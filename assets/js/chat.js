import {Socket} from "phoenix"

document.addEventListener("DOMContentLoaded", () => {
    const urlParams = new URLSearchParams(window.location.search)
    const roomId = urlParams.get("room_id")
    const userId = urlParams.get("userId");

    // room_id가 없으면 실행하지 않음 (예: /rooms 페이지)
    if (!roomId) {
        console.log("room_id 없음 → chat.js 실행 안함")
        return
    }

    // 채팅방 UI 요소 가져오기
    const messageList = document.getElementById("messages")
    const input = document.getElementById("message-input")
    const sendButton = document.getElementById("send-button")

    // 이 3개 요소가 모두 있어야 실행 (혹시 빠졌을 경우 안전하게)
    if (!messageList || !input || !sendButton) {
        console.log("필요한 채팅 UI 요소가 없음 → 실행 안함")
        return
    }

    // 소켓 연결
    const socket = new Socket("/socket", {params: {userToken: "123"}})
    socket.connect()

    // 채널 연결
    const channel = socket.channel(`room:${roomId}`, {})

    channel.join()
        .receive("ok", resp => {
            console.log(`✅ Joined room ${roomId}`, resp)
        })
        .receive("error", resp => {
            console.error("❌ Unable to join", resp)
        })

    // 메시지 수신
    channel.on("new_msg", payload => {
        const li = document.createElement("li")
        li.textContent = `${payload.user}: ${payload.message} (${payload.timestamp})`
        messageList.appendChild(li)
    })

    // 메시지 전송 함수 (클릭 + 엔터에서 같이 사용)
    function sendMessage() {
        const message = input.value
        if (message.trim() === "") return

        channel.push("new_msg", {
            id: roomId,
            user: userId,  // 유저 ID는 필요하면 동적으로 바꿀 수 있음
            message: message
        })

        input.value = ""
    }

    // 버튼 클릭 시 전송
    sendButton.addEventListener("click", sendMessage)

    // 엔터 입력 시 전송
    let isComposing = false;

    input.addEventListener("compositionstart", () => {
        isComposing = true;
    });

    input.addEventListener("compositionend", () => {
        isComposing = false;
        sendMessage();
    });

    input.addEventListener("keydown", (event) => {
        if (event.key === "Enter" && !isComposing) {
            event.preventDefault();
            sendMessage();
        }
    });
})