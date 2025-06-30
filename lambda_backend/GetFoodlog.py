import json
import os
import boto3
from datetime import datetime, time, timedelta
import pytz  # 시간대 처리를 위한 라이브러리

# DynamoDB 리소스 초기화
dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("TABLE_NAME", "food-logs")
table = dynamodb.Table(TABLE_NAME)

# 한국 시간대 설정
KST = pytz.timezone("Asia/Seoul")


def lambda_handler(event, context):
    """
    사용자의 음식 기록을 조회하는 API.
    - 쿼리 파라미터 없이 호출 시: 오늘 날짜의 기록 조회
    - ?year=YYYY&month=MM 호출 시: 해당 연월의 기록 조회
    """
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
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
                "body": json.dumps({"error": "Unauthorized"}),
            }

        # 2. 쿼리 파라미터 파싱
        params = event.get("queryStringParameters") or {}
        year_str = params.get("year")
        month_str = params.get("month")

        # 3. 조회할 시간 범위 결정
        now_kst = datetime.now(KST)

        if year_str and month_str:
            # 특정 연월 조회 (캘린더용)
            try:
                year = int(year_str)
                month = int(month_str)
                # 해당 월의 시작일과 마지막 날 계산
                start_dt_kst = KST.localize(datetime(year, month, 1))
                # 다음 달 1일에서 1초를 빼서 마지막 날의 끝 시간을 구함
                if month == 12:
                    end_dt_kst = KST.localize(datetime(year + 1, 1, 1)) - timedelta(
                        seconds=1
                    )
                else:
                    end_dt_kst = KST.localize(datetime(year, month + 1, 1)) - timedelta(
                        seconds=1
                    )
            except (ValueError, TypeError):
                return {
                    "statusCode": 400,
                    "headers": headers,
                    "body": json.dumps({"error": "Invalid year or month"}),
                }
        else:
            # 당일 기록 조회 (기본)
            start_dt_kst = now_kst.replace(hour=0, minute=0, second=0, microsecond=0)
            end_dt_kst = now_kst.replace(
                hour=23, minute=59, second=59, microsecond=999999
            )

        # 4. DynamoDB 쿼리를 위해 UTC로 변환 후 ISO 형식 문자열로 변환
        start_dt_utc = start_dt_kst.astimezone(pytz.utc)
        end_dt_utc = end_dt_kst.astimezone(pytz.utc)

        # ulid 변환 없이 바로 isoformat() 사용
        start_log_id = start_dt_utc.isoformat()

        # 월간 조회 시, 마지막 날의 가장 끝 시간을 포함하기 위해 ZZZ를 붙여줍니다.
        # 이렇게 하면 '2025-06-30T23:59:59.999999' 이후, '#'이 붙은 ID들까지 모두 포함됩니다.
        end_log_id = end_dt_utc.isoformat().replace("+00:00", "Z") + "ZZZ"

        # 5. 페이지네이션 처리
        # 클라이언트가 다음 페이지를 요청할 때 보낸 last_key를 받음
        exclusive_start_key = None
        last_key_str = params.get("last_key")
        if last_key_str:
            exclusive_start_key = json.loads(last_key_str)

        # 6. DynamoDB 쿼리 실행
        query_params = {
            "KeyConditionExpression": "user_id = :uid AND log_id BETWEEN :start AND :end",
            "ExpressionAttributeValues": {
                ":uid": user_id,
                ":start": start_log_id,
                ":end": end_log_id,
            },
            "ScanIndexForward": True,  # 시간순 (오름차순)으로 정렬
        }

        if exclusive_start_key:
            query_params["ExclusiveStartKey"] = exclusive_start_key

        response = table.query(**query_params)

        # 7. 응답 데이터 구성
        # 다음 페이지가 있는 경우, LastEvaluatedKey를 클라이언트에 전달
        result = {
            "items": response.get("Items", []),
            "last_evaluated_key": response.get("LastEvaluatedKey", None),
        }

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps(
                result, default=str
            ),  # Decimal 타입 등을 위해 default=str
        }

    except Exception as e:
        print(f"Internal Server Error: {e}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": "Internal Server Error"}),
        }
