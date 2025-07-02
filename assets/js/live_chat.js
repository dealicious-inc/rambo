import {Socket} from "phoenix"

document.addEventListener("DOMContentLoaded", () => {
    const root = document.querySelector("#live-chat")
    if (!root) return

    const urlParams = new URLSearchParams(window.location.search)
    const roomId = urlParams.get("room_id")
    const userId = urlParams.get("userId")
    const userName = urlParams.get("userName")
    const roomName = urlParams.get("room_name")

    if (!roomId || !userId) {
        console.warn("❌ room_id 또는 userId 누락됨")
        return
    }

    // 🧭 뒤로가기 버튼
    const backButton = document.getElementById("back-button")
    if (backButton) {
        backButton.addEventListener("click", () => {
            window.location.href = `/rooms?userId=${userId}`
        })
    }

    // 🧾 채팅 UI 요소
    const messageList = document.getElementById("messages")
    const input = document.getElementById("message-input")
    const sendButton = document.getElementById("send-button")

    if (!messageList || !input || !sendButton) {
        console.warn("❌ 필수 UI 요소 누락")
        return
    }

    // 💬 Socket 연결 및 채널 조인
    const socket = new Socket("/socket", {params: {userToken: "123"}})
    socket.connect()

    const channel = socket.channel(`room:${roomId}`, {
        user_id: userId,
        user_name: userName
    })

    channel.join()
        .receive("ok", () => console.log("✅ 채널 조인 완료"))
        .receive("error", err => console.error("❌ 채널 조인 실패", err))

    // 📥 메시지 수신 처리
    channel.on("new_msg", (payload) => {
        const li = document.createElement("li")
        const type = payload.type || "chat"
        const time = new Date(payload.timestamp)
        const formatted = `${time.getHours().toString().padStart(2, "0")}:${time.getMinutes().toString().padStart(2, "0")}`

        if (type === "notice") {
            li.textContent = `📢 ${payload.message}`
            li.style.textAlign = "center"
            li.style.fontWeight = "bold"
            li.style.color = "#c0392b"
        } else if (type === "system") {
            li.textContent = payload.message
            li.style.textAlign = "center"
            li.style.fontStyle = "italic"
            li.style.color = "gray"
        } else {
            const messageText = document.createElement("span")
            messageText.textContent = `${payload.user_name}: ${payload.message}`

            const timeText = document.createElement("span")
            timeText.textContent = ` ${formatted}`
            timeText.style.fontSize = "0.8em"
            timeText.style.color = "gray"
            timeText.style.marginLeft = "8px"

            li.appendChild(messageText)
            li.appendChild(timeText)
        }

        messageList.appendChild(li)
    })

    // 🙋 사용자 수 수신
    channel.on("user_count", payload => {
        const label = document.getElementById("user-count")
        if (label) label.innerText = `👥 ${payload.count}명 참여 중`
    })

    // 🚫 채팅 금지 알림
    channel.on("ban_chat", payload => {
        const li = document.createElement("li")
        li.textContent = payload.reason || "채팅 제한 중입니다."
        li.style.color = "red"
        messageList.appendChild(li)
    })

    // 🏷️ 방 이름 표시
    const roomNameLabel = document.getElementById("room-name")
    if (roomName && roomNameLabel) {
        roomNameLabel.innerText = decodeURIComponent(roomName)
    }

    // 📤 메시지 전송 함수
    function sendMessage() {
        const message = input.value.trim()
        if (message === "") return

        channel.push("send_live_msg", {
            id: roomId,
            user_id: userId,
            user_name: userName,
            message: message
        })

        input.value = ""
    }

    // 전송 이벤트 연결
    sendButton.addEventListener("click", sendMessage)
    let isComposing = false

    input.addEventListener("compositionstart", () => isComposing = true)
    input.addEventListener("compositionend", () => isComposing = false)
    input.addEventListener("keydown", (e) => {
        if (e.key === "Enter" && !isComposing) {
            e.preventDefault()
            sendMessage()
        }
    })

    // 🛡️ 신고하기 UI 처리
    const reportButton = document.getElementById("report-button")
    const reportModal = document.getElementById("report-modal")
    const closeModal = document.getElementById("close-report-modal")
    const reportUserList = document.getElementById("report-user-list")

    if (reportButton && reportModal && closeModal && reportUserList) {
        reportButton.addEventListener("click", () => {
            fetch(`/api/rooms/${roomId}/participate-users`)
                .then(res => res.json())
                .then(data => {
                    reportUserList.innerHTML = ""
                    data.users.forEach(user => {
                        if (String(user.user_id) === String(userId)) return

                        const li = document.createElement("li")
                        li.style.marginBottom = "8px"

                        const span = document.createElement("span")
                        span.textContent = user.user_name
                        span.style.marginRight = "8px"

                        const btn = document.createElement("button")
                        btn.textContent = "신고"
                        Object.assign(btn.style, {
                            padding: "2px 8px",
                            backgroundColor: "#e74c3c",
                            color: "white",
                            border: "none",
                            borderRadius: "4px",
                            cursor: "pointer"
                        })

                        btn.addEventListener("click", () => {
                            fetch("/api/rooms/ban-user", {
                                method: "POST",
                                headers: {"Content-Type": "application/json"},
                                body: JSON.stringify({user_id: user.user_id})
                            })
                                .then(res => res.json())
                                .then(() => {
                                    alert("✅ 신고 완료: 5분간 채팅이 제한됩니다.")
                                    reportModal.style.display = "none"
                                })
                                .catch(err => {
                                    alert("❌ 신고 실패")
                                    console.error(err)
                                })
                        })

                        li.appendChild(span)
                        li.appendChild(btn)
                        reportUserList.appendChild(li)
                    })

                    reportModal.style.display = "block"
                })
                .catch(err => {
                    alert("❌ 사용자 목록 불러오기 실패")
                    console.error(err)
                })
        })

        closeModal.addEventListener("click", () => {
            reportModal.style.display = "none"
        })
    }
})