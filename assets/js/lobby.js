import { Socket } from "phoenix"

document.addEventListener("DOMContentLoaded", () => {
    const roomListEl = document.getElementById("user-room-list")

    // 리스트를 표시할 엘리먼트가 없으면 종료
    if (!roomListEl) {
        console.log("room-list 요소 없음 → lobby.js 종료")
        return
    }

    const userId = 1

    const socket = new Socket("/socket", { params: { user_id: userId } })
    socket.connect()

    const channel = socket.channel(`user_lobby:${userId}`, {})

    channel.join()
        .receive("ok", () => {
            console.log("✅ 로비 채널 접속 성공")
        })
        .receive("error", () => {
            console.error("❌ 로비 채널 접속 실패")
        })

    // 서버로부터 채팅방 목록을 수신
    channel.on("room_list", payload => {
        roomListEl.innerHTML = ""

        payload.rooms.forEach(room => {
            const li = document.createElement("li")
            li.textContent = `${room.name} (${room.unread_count} unread)`

            // 클릭 시 해당 채팅방 페이지로 이동
            li.addEventListener("click", () => {
                window.location.href = `/chat?room_id=${room.id}`
            })

            roomListEl.appendChild(li)
        })
    })
})