import json
import boto3
import os
from datetime import date

# boto3 클라이언트 초기화
cognito_client = boto3.client("cognito-idp")

# Lambda 환경 변수에서 User Pool ID 가져오기
USER_POOL_ID = os.environ.get("USER_POOL_ID")


def calculate_nutritional_goals(
    birthdate_str, height_cm, weight_kg, gender, activity_level, goal
):
    """
    Mifflin-St Jeor equation - 사용자 정보와 목표에 기반하여 일일 권장 섭취량을 계산합니다.
    """
    # 1. 나이 계산
    today = date.today()
    birthdate = date.fromisoformat(birthdate_str)
    age = (
        today.year
        - birthdate.year
        - ((today.month, today.day) < (birthdate.month, birthdate.day))
    )

    # 2. BMR 계산 (미플린-지어 방정식)
    if gender == "male":
        bmr = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + 5
    else:  # female
        bmr = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) - 161

    # 3. TDEE 계산 (활동량 계수 적용)
    activity_multipliers = {
        "sedentary": 1.2,
        "light": 1.375,
        "moderate": 1.55,
        "very": 1.725,
        "extra": 1.9,
    }
    tdee = bmr * activity_multipliers[activity_level]

    # 4. 목표 칼로리 설정
    goal_adjustments = {"lose": -500, "maintain": 0, "gain": 300}
    target_calories = tdee + goal_adjustments[goal]

    # 5. 영양소 배분 (칼로리 기준: 탄수화물 40%, 단백질 30%, 지방 30%)
    # 1g당 칼로리: 탄수화물=4, 단백질=4, 지방=9
    target_carbs = (target_calories * 0.40) / 4
    target_protein = (target_calories * 0.30) / 4
    target_fats = (target_calories * 0.30) / 9

    return {
        "calories": round(target_calories),
        "carbs": round(target_carbs),
        "protein": round(target_protein),
        "fats": round(target_fats),
    }


def lambda_handler(event, context):
    """
    온보딩 프로필 정보를 받아 목표를 계산하고 Cognito 사용자 속성을 업데이트합니다.
    """
    try:
        user_sub = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    except (KeyError, TypeError):
        return {"statusCode": 401, "body": json.dumps({"error": "Unauthorized"})}

    try:
        body = json.loads(event.get("body", "{}"))

        # 목표(goal) 필드 추가 검사
        required_fields = [
            "birthdate",
            "height",
            "weight",
            "gender",
            "activity_level",
            "goal",
        ]
        if not all(field in body for field in required_fields):
            return {
                "statusCode": 400,
                "body": json.dumps(
                    {
                        "error": f"Bad Request: Missing fields. Required: {required_fields}"
                    }
                ),
            }

        valid_activity_levels = ["sedentary", "light", "moderate", "very", "extra"]
        if body["activity_level"] not in valid_activity_levels:
            return {
                "statusCode": 400,
                "body": json.dumps(
                    {
                        "error": f"Bad Request: activity_level must be one of {valid_activity_levels}"
                    }
                ),
            }

        # 목표 값 검사
        if body["goal"] not in ["lose", "maintain", "gain"]:
            return {
                "statusCode": 400,
                "body": json.dumps(
                    {"error": "Bad Request: goal must be lose, maintain, or gain"}
                ),
            }

    except (json.JSONDecodeError, TypeError):
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Bad Request: Invalid JSON format"}),
        }

    try:
        # 헬퍼 함수를 호출하여 목표 영양소 계산
        goals = calculate_nutritional_goals(
            birthdate_str=body["birthdate"],
            height_cm=float(body["height"]),
            weight_kg=float(body["weight"]),
            gender=body["gender"],
            activity_level=body["activity_level"],
            goal=body["goal"],
        )

        # Cognito에 업데이트할 속성 목록 구성 (기존 정보 + 계산된 정보)
        user_attributes = [
            {"Name": "birthdate", "Value": body["birthdate"]},
            {"Name": "gender", "Value": body["gender"]},
            {"Name": "custom:height", "Value": str(body["height"])},
            {"Name": "custom:weight", "Value": str(body["weight"])},
            {"Name": "custom:activity_level", "Value": body["activity_level"]},
            {
                "Name": "custom:goal",
                "Value": body["goal"],
            },  # 사용자의 목표도 저장 (선택 사항)
            # 계산된 목표치 추가
            {"Name": "custom:target_calories", "Value": str(goals["calories"])},
            {"Name": "custom:target_carbs", "Value": str(goals["carbs"])},
            {"Name": "custom:target_protein", "Value": str(goals["protein"])},
            {"Name": "custom:target_fats", "Value": str(goals["fats"])},
        ]

        # Cognito API 호출
        cognito_client.admin_update_user_attributes(
            UserPoolId=USER_POOL_ID, Username=user_sub, UserAttributes=user_attributes
        )

        return {
            "statusCode": 200,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps(
                {
                    "message": "User profile and goals updated successfully",
                    "calculatedGoals": goals,  # 계산된 값을 앱에도 바로 돌려주어 화면에 표시하게 할 수 있음
                }
            ),
        }

    except Exception as e:
        print(f"Error during processing or Cognito update: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"}),
        }
