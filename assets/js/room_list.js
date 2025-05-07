document.addEventListener("DOMContentLoaded", () => {
    const roomList = document.getElementById("room-list")

    if (!roomList) {
        console.warn("room-list 요소가 없습니다.")
        return
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
                    window.location.href = `/chat?room_id=${room.id}&room_name=${encodeURIComponent(room.name)}`
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