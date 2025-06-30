import json
import os
import boto3
from datetime import datetime, timezone
import uuid

# DynamoDB 리소스 초기화
dynamodb = boto3.resource("dynamodb")
# Lambda 환경 변수에서 테이블 이름 가져오기
TABLE_NAME = os.environ.get("TABLE_NAME", "food-logs")
table = dynamodb.Table(TABLE_NAME)

# Lambda 환경 변수에서 이미지 기본 URL 가져오기
IMAGE_BASE_URL = os.environ.get("IMAGE_BASE_URL")


def lambda_handler(event, context):
    """
    API Gateway를 통해 음식 기록(영양소 포함)을 받아 DynamoDB에 저장하는 메인 핸들러
    """
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
    }

    try:
        # 1. 사용자 인증 정보 가져오기
        claims = (
            event.get("requestContext", {})
            .get("authorizer", {})
            .get("jwt", {})
            .get("claims", {})
        )
        user_id = claims.get("sub")

        if not user_id:
            return {
                "statusCode": 401,
                "headers": headers,
                "body": json.dumps(
                    {"error": "Unauthorized: User ID not found in token."}
                ),
            }

        # 2. 요청 Body 파싱 및 유효성 검사
        body = json.loads(event.get("body", "{}"))

        # --- [영양소 추가 1/3] 필수 필드 목록에 영양소 추가 ---
        required_fields = ["food_name", "calories", "protein", "carbs", "fat"]
        if not all(field in body for field in required_fields):
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps(
                    {
                        "error": f"Bad Request: Missing one or more required fields. Required: {required_fields}"
                    }
                ),
            }

        food_name = body.get("food_name")
        calories = body.get("calories")
        protein = body.get("protein")
        carbs = body.get("carbs")
        fat = body.get("fat")
        image_key = body.get("imageUrl")

        # 3. DynamoDB에 저장할 아이템 생성
        now = datetime.now(timezone.utc)
        # Partition Key(user_id)와 Sort Key(log_id)를 조합하여 아이템을 고유하게 식별
        log_id = f"{now.isoformat()}"
        eaten_at = body.get("eaten_at", now.isoformat())

        item = {
            "user_id": user_id,
            "log_id": log_id,
            "food_name": food_name,
            "calories": int(calories),
            # --- [영양소 추가 2/3] 아이템에 영양소 정보 추가 ---
            "protein": int(protein),
            "carbs": int(carbs),
            "fat": int(fat),
            # ---
            "meal_type": body.get(
                "meal_type", "ETC"
            ),  # 예: 'breakfast', 'lunch', 'dinner', 'snack'
            "eaten_at": eaten_at,  # 사용자가 식사 시간을 직접 선택한 경우
            "created_at": now.isoformat(),
        }

        # image_key가 제공된 경우, 전체 이미지 URL을 생성하여 추가
        if image_key:
            if not IMAGE_BASE_URL:
                print("ERROR: IMAGE_BASE_URL environment variable is not set.")
                return {
                    "statusCode": 500,
                    "headers": headers,
                    "body": json.dumps(
                        {
                            "error": "Internal Server Error: Image URL configuration is missing."
                        }
                    ),
                }

            full_image_url = f"{IMAGE_BASE_URL.rstrip('/')}/{image_key.lstrip('/')}"
            item["image_url"] = full_image_url

        # 4. DynamoDB에 아이템 저장
        table.put_item(Item=item)

        # 5. 성공 응답 반환
        return {
            "statusCode": 201,  # 201 Created
            "headers": headers,
            "body": json.dumps(
                {
                    "message": "Food log saved successfully.",
                    "item": item,  # 저장된 아이템 전체를 반환하여 클라이언트가 상태를 업데이트하게 할 수 있음
                }
            ),
        }

    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "headers": headers,
            "body": json.dumps({"error": "Bad Request: Invalid JSON format."}),
        }
    except Exception as e:
        print(f"Internal Server Error: {e}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": "Internal Server Error"}),
        }
