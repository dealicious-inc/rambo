from locust import HttpUser, task, between

class QuickstartUser(HttpUser):
    # 각 태스크 사이에 1~5초 대기
    wait_time = between(1, 5)

    # 기본 URL 설정 (실제 테스트할 서버 URL로 변경 필요)
    host = "http://localhost:5000"  # Flask 서버 URL

    @task
    def index_page(self):
        # 메인 페이지 접속
        self.client.get("/")

    @task
    def view_posts(self):
        # 게시물 목록 페이지 접속
        self.client.get("/post")
