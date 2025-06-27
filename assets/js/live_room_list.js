document.addEventListener("DOMContentLoaded", () => {
    const roomList = document.getElementById("room-list")
    const params = new URLSearchParams(window.location.search);

    if (!roomList) {
        console.warn("room-list 요소가 없습니다.")
        return
    }

    const userId = parseInt(params.get("userId"));
    if (!userId) {
        alert("❗ URL에 userId 쿼리 파라미터가 필요합니다. 예: /live_chat?userId=1");
        return;
    }

    // 서버에서 방 목록 가져오기
    fetch("/api/rooms")
        .then(response => {
            if (!response.ok) {
                throw new Error("방 목록 가져오기 실패")
            }
            return response.json()
        })
        .then(rooms => {
            rooms.forEach(room => {
                const li = document.createElement("li")
                li.textContent = room.name
                li.style.cursor = "pointer"
                li.style.color = "blue"
                li.style.textDecoration = "underline"

                li.addEventListener("click", () => {
                    window.location.href = `/live_chat?room_id=${room.id}&room_name=${encodeURIComponent(room.name)}&userId=${userId}`
                })

                roomList.appendChild(li)
            })
        })
        .catch(error => {
            console.error("방 목록 로드 에러:", error)
            const li = document.createElement("li")
            li.textContent = "방 목록을 불러올 수 없습니다."
            roomList.appendChild(li)
        })
})