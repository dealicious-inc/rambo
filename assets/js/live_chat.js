import {Socket} from "phoenix"

document.addEventListener("DOMContentLoaded", () => {
    const urlParams = new URLSearchParams(window.location.search)
    const root = document.querySelector("#live-chat")
    if (!root) return
    console.log("✅ live_chat.js 실행됨")
    const roomId = urlParams.get("room_id")
    const userId = urlParams.get("userId");
    const userName = urlParams.get("userName");

    // room_id가 없으면 실행하지 않음 (예: /rooms 페이지)
    if (!roomId) {
        console.log("room_id 없음 → live_chat.js 실행 안함")
        return
    }

    if (!userId) {
        console.error("userId 누락됨, 채널 join 불가")
        return
    }

    const backButton = document.getElementById("back-button")
    if (backButton && userId) {
        backButton.addEventListener("click", () => {
            window.location.href = `/rooms?userId=${userId}`;
        })
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
    const channel = socket.channel(`room:${roomId}`, { user_id: userId })
    channel.join()
        .receive("ok", () => {
            console.log("Joining channel with:", { user_id: userId })
        })
        .receive("error", resp => {
            console.error("❌ Unable to join", resp)
        })

    // 메시지 수신
    channel.on("new_msg", (payload) => {
        const li = document.createElement("li")

        const messageText = document.createElement("span")
        messageText.textContent = `${payload.user_name}: ${payload.message}`

        const timeText = document.createElement("span")
        const time = new Date(payload.timestamp)
        const formatted = `${time.getHours().toString().padStart(2, "0")}:${time.getMinutes().toString().padStart(2, "0")}`
        timeText.textContent = ` ${formatted}`
        timeText.style.fontSize = "0.8em"
        timeText.style.color = "gray"
        timeText.style.marginLeft = "8px"

        li.appendChild(messageText)
        li.appendChild(timeText)

        messageList.appendChild(li)
    })

    channel.on("user_count", payload => {
        const label = document.getElementById("user-count");
        if (label) label.innerText = `👥 ${payload.count}명 참여 중`;
    });

    const roomName = urlParams.get("room_name")
    const roomNameLabel = document.getElementById("room-name")

    if (roomName && roomNameLabel) {
        roomNameLabel.innerText = decodeURIComponent(roomName)
        roomNameLabel.style.fontSize = "20px"
    }
    // 메시지 전송 함수 (클릭 + 엔터에서 같이 사용)
    function sendMessage() {
        const message = input.value
        if (message.trim() === "") return

        channel.push("send_live_msg", {
            id: roomId,
            user_id: userId,
            user_name: userName,
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
    });

    input.addEventListener("keydown", (event) => {
        if (event.key === "Enter" && !isComposing) {
            event.preventDefault();
            sendMessage();
        }
    });
})

