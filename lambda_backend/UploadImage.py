import json
import boto3
import uuid
import os

s3_client = boto3.client("s3")
BUCKET_NAME = os.environ.get("BUCKET_NAME")  # Lambda 환경 변수에서 버킷 이름 가져오기


def lambda_handler(event, context):
    # CORS 헤더 정의
    cors_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token, X-Requested-With",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Max-Age": "86400",  # 24시간 캐시
    }

    # HTTP 메서드 확인
    http_method = event.get("requestContext", {}).get("http", {}).get("method")

    print(http_method)

    # OPTIONS 요청 처리 (CORS preflight)
    if http_method == "OPTIONS":
        return {"statusCode": 200, "headers": cors_headers, "body": ""}

    # GET 요청이 아닌 경우
    if http_method != "GET":
        return {
            "statusCode": 405,
            "headers": cors_headers,
            "body": json.dumps({"error": "Method not allowed"}),
        }

    try:
        # 실제 앱에서는 Cognito 등 인증 정보를 통해 사용자 ID를 가져와야 함
        # 예시에서는 임의의 사용자 ID를 사용
        claims = (
            event.get("requestContext", {})
            .get("authorizer", {})
            .get("jwt", {})
            .get("claims", {})
        )
        user_id = claims.get("sub")
        print(user_id)
        if not user_id:
            return {
                "statusCode": 401,
                "body": json.dumps(
                    {"error": "Unauthorized: User ID not found in token"}
                ),
            }

        # 고유한 파일명과 S3 객체 키(경로) 생성
        file_name = f"{uuid.uuid4()}.jpg"
        object_key = f"uploads/{user_id}/{file_name}"
        print(object_key)
        # 5분 동안 유효한 Pre-signed URL 생성
        presigned_url = s3_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": BUCKET_NAME,
                "Key": object_key,
                "ContentType": "image/jpeg",
            },
            ExpiresIn=300,  # URL 유효 시간 (초)
        )
        print(presigned_url)
        return {
            "statusCode": 200,
            "headers": cors_headers,
            "body": json.dumps(
                {
                    "uploadUrl": presigned_url,
                    "objectKey": object_key,  # 업로드 후 분석 요청에 사용할 키
                    "filename": file_name,
                }
            ),
        }

    except Exception as e:
        print(f"Error generating presigned URL: {e}")
        return {
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({"error": str(e)}),
        }
