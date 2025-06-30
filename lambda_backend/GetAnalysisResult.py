import json
import boto3
import os
from decimal import Decimal  # Decimal 타입을 사용하기 위해 import

# DynamoDB 리소스 초기화
dynamodb = boto3.resource("dynamodb")
RESULTS_TABLE_NAME = os.environ.get("RESULTS_TABLE_NAME")
table = dynamodb.Table(RESULTS_TABLE_NAME)


# --- [수정된 부분 1] ---
# Decimal 타입을 JSON으로 변환하기 위한 커스텀 인코더 클래스
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        # obj가 Decimal 타입인지 확인
        if isinstance(obj, Decimal):
            # 정수인지 실수인지 확인하여 변환
            if obj % 1 == 0:
                return int(obj)
            else:
                return float(obj)
        # 그 외의 타입은 기본 인코더에게 맡김
        return super(DecimalEncoder, self).default(obj)


# --- 수정 끝 ---


def lambda_handler(event, context):
    """
    analysisId를 기반으로 DynamoDB에서 분석 결과를 조회합니다.
    """
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
    }

    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return {"statusCode": 204, "headers": headers, "body": ""}

    try:
        analysis_id = event.get("pathParameters", {}).get("analysisId")

        if not analysis_id:
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps(
                    {"error": "Bad Request: analysisId is missing from the path."}
                ),
            }

        response = table.get_item(Key={"analysisId": analysis_id})

        if "Item" in response:
            item = response["Item"]
            return {
                "statusCode": 200,
                "headers": headers,
                # --- [수정된 부분 2] ---
                # json.dumps 호출 시, 위에서 만든 DecimalEncoder를 cls 파라미터로 지정
                "body": json.dumps(item, cls=DecimalEncoder),
                # --- 수정 끝 ---
            }
        else:
            return {
                "statusCode": 202,
                "headers": headers,
                "body": json.dumps(
                    {"status": "PENDING", "message": "Analysis is still in progress."}
                ),
            }

    except Exception as e:
        print(f"An error occurred: {e}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": "Internal Server Error"}),
        }
