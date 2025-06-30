import json
import boto3
import os
import uuid

# Boto3 클라이언트 초기화
sqs_client = boto3.client("sqs")

# Lambda 환경 변수에서 리소스 이름 가져오기
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")


def lambda_handler(event, context):
    """
    분석 요청을 받아 SQS에 작업을 등록하고,
    클라이언트에게는 즉시 추적 ID(analysisId)를 반환합니다.
    """
    headers = {"Access-Control-Allow-Origin": "*"}

    try:
        # 1. 요청 Body에서 objectKey 가져오기
        body = json.loads(event.get("body", "{}"))
        object_key = body.get("objectKey")
        if not object_key:
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps({"error": "Bad Request: objectKey is required."}),
            }

        # 2. 고유한 analysisId 생성 (핵심)
        analysis_id = str(uuid.uuid4())

        # 3. SQS에 보낼 메시지 본문 구성
        message_body = json.dumps({"analysisId": analysis_id, "objectKey": object_key})

        # 4. SQS 대기열에 메시지 전송
        sqs_client.send_message(QueueUrl=SQS_QUEUE_URL, MessageBody=message_body)

        print(f"Successfully enqueued analysis job. ID: {analysis_id}")

        # 5. 클라이언트에게 analysisId를 즉시 반환 (핵심)
        return {
            "statusCode": 202,  # 202 Accepted: 요청이 접수되었으나 처리가 완료되지 않음
            "headers": headers,
            "body": json.dumps(
                {"message": "Analysis request accepted.", "analysisId": analysis_id}
            ),
        }

    except Exception as e:
        print(f"Error requesting analysis: {e}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": "Internal server error"}),
        }
