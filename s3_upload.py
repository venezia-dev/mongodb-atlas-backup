#!/usr/bin/env python3
"""
S3 Upload Script for MongoDB Backups
Supports multipart uploads, progress tracking, and robust error handling
"""

import os
import sys
import hashlib
import logging
from datetime import datetime
from typing import Optional, Tuple
from pathlib import Path

import boto3
from botocore.exceptions import ClientError, NoCredentialsError
from botocore.config import Config


class S3Uploader:
    def __init__(self):
        self.bucket = os.getenv('S3_BUCKET')
        self.prefix = os.getenv('S3_PREFIX', 'mongodb-backups/')
        self.storage_class = os.getenv('S3_STORAGE_CLASS', 'STANDARD')
        self.multipart_threshold = self._parse_size(os.getenv('MULTIPART_THRESHOLD', '100MB'))
        
        # AWS Config with retry logic
        config = Config(
            region_name=os.getenv('AWS_DEFAULT_REGION', 'us-east-1'),
            retries={
                'max_attempts': 3,
                'mode': 'adaptive'
            }
        )
        
        try:
            self.s3_client = boto3.client('s3', config=config)
        except NoCredentialsError:
            print("ERROR: AWS credentials not configured")
            sys.exit(1)
            
        # Setup logging
        logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
        self.logger = logging.getLogger(__name__)

    def _parse_size(self, size_str: str) -> int:
        """Convert size string like '100MB' to bytes"""
        size_str = size_str.upper()
        if size_str.endswith('MB'):
            return int(size_str[:-2]) * 1024 * 1024
        elif size_str.endswith('GB'):
            return int(size_str[:-2]) * 1024 * 1024 * 1024
        else:
            return int(size_str)

    def _calculate_md5(self, file_path: str) -> str:
        """Calculate MD5 hash of file for integrity verification"""
        hash_md5 = hashlib.md5()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()

    def _get_s3_key(self, file_path: str) -> str:
        """Generate S3 key with organized folder structure"""
        filename = Path(file_path).name
        now = datetime.now()
        
        # Extract date from filename if possible, otherwise use current date
        date_part = now.strftime('%Y-%m-%d')
        if '_' in filename:
            try:
                # Extract date from filename like backup_dbname_20240824_174004.gz
                parts = filename.split('_')
                if len(parts) >= 3 and len(parts[2]) == 8:
                    date_str = parts[2]  # 20240824
                    date_part = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
            except (IndexError, ValueError):
                pass  # Use current date if extraction fails
        
        return f"{self.prefix}{date_part}/{filename}"

    def _upload_small_file(self, file_path: str, s3_key: str) -> Tuple[bool, str]:
        """Upload small files using simple put_object"""
        try:
            md5_hash = self._calculate_md5(file_path)
            file_size = os.path.getsize(file_path)
            
            self.logger.info(f"Uploading {file_path} ({file_size:,} bytes) to s3://{self.bucket}/{s3_key}")
            
            with open(file_path, 'rb') as f:
                self.s3_client.put_object(
                    Bucket=self.bucket,
                    Key=s3_key,
                    Body=f,
                    StorageClass=self.storage_class,
                    Metadata={
                        'original-filename': Path(file_path).name,
                        'md5-hash': md5_hash,
                        'upload-timestamp': datetime.utcnow().isoformat()
                    }
                )
            
            return True, f"Small file upload successful. MD5: {md5_hash}"
            
        except ClientError as e:
            error_msg = f"AWS S3 upload failed: {e}"
            self.logger.error(error_msg)
            return False, error_msg
        except Exception as e:
            error_msg = f"Upload failed: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg

    def _upload_multipart(self, file_path: str, s3_key: str) -> Tuple[bool, str]:
        """Upload large files using multipart upload"""
        try:
            file_size = os.path.getsize(file_path)
            md5_hash = self._calculate_md5(file_path)
            
            self.logger.info(f"Starting multipart upload for {file_path} ({file_size:,} bytes)")
            
            # Initialize multipart upload
            response = self.s3_client.create_multipart_upload(
                Bucket=self.bucket,
                Key=s3_key,
                StorageClass=self.storage_class,
                Metadata={
                    'original-filename': Path(file_path).name,
                    'md5-hash': md5_hash,
                    'upload-timestamp': datetime.utcnow().isoformat()
                }
            )
            
            upload_id = response['UploadId']
            parts = []
            part_size = 100 * 1024 * 1024  # 100MB parts
            part_number = 1
            
            with open(file_path, 'rb') as f:
                while True:
                    data = f.read(part_size)
                    if not data:
                        break
                    
                    # Upload part
                    part_response = self.s3_client.upload_part(
                        Bucket=self.bucket,
                        Key=s3_key,
                        PartNumber=part_number,
                        UploadId=upload_id,
                        Body=data
                    )
                    
                    parts.append({
                        'ETag': part_response['ETag'],
                        'PartNumber': part_number
                    })
                    
                    progress = (part_number * part_size) / file_size * 100
                    self.logger.info(f"Uploaded part {part_number} ({min(progress, 100):.1f}%)")
                    part_number += 1
            
            # Complete multipart upload
            self.s3_client.complete_multipart_upload(
                Bucket=self.bucket,
                Key=s3_key,
                UploadId=upload_id,
                MultipartUpload={'Parts': parts}
            )
            
            return True, f"Multipart upload successful ({len(parts)} parts). MD5: {md5_hash}"
            
        except ClientError as e:
            # Abort multipart upload on error
            try:
                if 'upload_id' in locals():
                    self.s3_client.abort_multipart_upload(
                        Bucket=self.bucket,
                        Key=s3_key,
                        UploadId=upload_id
                    )
            except:
                pass
            
            error_msg = f"Multipart upload failed: {e}"
            self.logger.error(error_msg)
            return False, error_msg
        except Exception as e:
            error_msg = f"Multipart upload failed: {str(e)}"
            self.logger.error(error_msg)
            return False, error_msg

    def upload_file(self, file_path: str) -> Tuple[bool, str, str]:
        """
        Upload file to S3 with automatic multipart for large files
        Returns: (success, message, s3_url)
        """
        if not os.path.exists(file_path):
            return False, f"File not found: {file_path}", ""
        
        if not self.bucket:
            return False, "S3_BUCKET not configured", ""
        
        s3_key = self._get_s3_key(file_path)
        file_size = os.path.getsize(file_path)
        
        # Choose upload method based on file size
        if file_size > self.multipart_threshold:
            success, message = self._upload_multipart(file_path, s3_key)
        else:
            success, message = self._upload_small_file(file_path, s3_key)
        
        if success:
            s3_url = f"s3://{self.bucket}/{s3_key}"
            return True, message, s3_url
        else:
            return False, message, ""

    def verify_upload(self, file_path: str, s3_key: str) -> bool:
        """Verify uploaded file integrity"""
        try:
            # Get object metadata
            response = self.s3_client.head_object(Bucket=self.bucket, Key=s3_key)
            
            # Check if file sizes match
            local_size = os.path.getsize(file_path)
            s3_size = response['ContentLength']
            
            return local_size == s3_size
            
        except ClientError:
            return False


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 s3_upload.py <file_path>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    # Check if S3 upload is enabled
    if os.getenv('S3_UPLOAD', 'false').lower() != 'true':
        print("S3_UPLOAD is disabled")
        sys.exit(0)
    
    uploader = S3Uploader()
    success, message, s3_url = uploader.upload_file(file_path)
    
    if success:
        print(f"SUCCESS: {message}")
        print(f"S3 URL: {s3_url}")
        sys.exit(0)
    else:
        print(f"ERROR: {message}")
        sys.exit(1)


if __name__ == "__main__":
    main()