import json
import boto3
import os

cognito_client = boto3.client("cognito-idp")
USER_POOL_ID = os.environ.get("USER_POOL_ID")


def lambda_handler(event, context):
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
    }

    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return {"statusCode": 204, "headers": headers, "body": ""}

    try:
        user_sub = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    except (KeyError, TypeError):
        return {
            "statusCode": 401,
            "headers": headers,
            "body": json.dumps({"error": "Unauthorized"}),
        }

    try:
        response = cognito_client.admin_get_user(
            UserPoolId=USER_POOL_ID, Username=user_sub
        )

        # --- [수정된 부분] ---

        # 1. 반환할 프로필의 기본 형태(템플릿)를 정의합니다. (모든 키 포함, 값은 None)
        default_profile = {
            "sub": None,
            "email": None,
            "email_verified": None,
            "birthdate": None,
            "gender": None,
            "height": None,
            "weight": None,
            "activity_level": None,
            "goal": None,
            "target_calories": None,
            "target_carbs": None,
            "target_protein": None,
            "target_fats": None,
        }

        # 2. Cognito 응답에서 실제로 존재하는 값들로 템플릿을 업데이트합니다.
        for attr in response["UserAttributes"]:
            key = attr["Name"].replace("custom:", "")

            # 템플릿에 해당 키가 있을 경우에만 값을 업데이트
            if key in default_profile:
                value = attr["Value"]
                # 숫자 변환 로직 (이전과 동일)
                if key in [
                    "height",
                    "weight",
                    "target_calories",
                    "target_carbs",
                    "target_protein",
                    "target_fats",
                ]:
                    try:
                        value = int(value)
                    except ValueError:
                        try:
                            value = float(value)
                        except ValueError:
                            pass

                default_profile[key] = value

        # Cognito 응답의 Username ('sub')도 추가해줍니다.
        default_profile["sub"] = response["Username"]
        # --- 수정 끝 ---

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps(default_profile),  # 항상 완전한 형태의 프로필을 반환
        }

    except cognito_client.exceptions.UserNotFoundException:
        return {
            "statusCode": 404,
            "headers": headers,
            "body": json.dumps({"error": "User not found"}),
        }
    except Exception as e:
        print(f"Internal Server Error: {e}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": "Internal Server Error"}),
        }
