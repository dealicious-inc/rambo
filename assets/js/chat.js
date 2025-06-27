import {Socket} from "phoenix"

document.addEventListener("DOMContentLoaded", () => {
    const root = document.querySelector("#chat-root")
    if (!root) return
    console.log("✅ chat.js 실행됨")
    const urlParams = new URLSearchParams(window.location.search)
    const roomId = urlParams.get("room_id")
    const userId = urlParams.get("userId");

    // room_id가 없으면 실행하지 않음 (예: /rooms 페이지)
    if (!roomId) {
        console.log("room_id 없음 → chat.js 실행 안함")
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
        .receive("ok", resp => {
            console.log("Joining channel with:", { user_id: userId })
        })
        .receive("error", resp => {
            console.error("❌ Unable to join", resp)
        })

    // 메시지 수신
    channel.on("new_msg", payload => {
        const li = document.createElement("li")
        li.textContent = `${payload.user}: ${payload.content} (${payload.timestamp})`
        messageList.appendChild(li)
    })

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

let Chat = {
  init(socket, element) {
    // ... (init 함수 윗부분은 변경 없음)

    this.renderMessages(messages)
  },

  renderMessages(messages) {
    const loggedInUserId = document.body.dataset.userId; // 현재 로그인한 사용자 ID 가져오기

    let messagesHTML = messages.map(msg => {
      const isMine = msg.sender_id.toString() === loggedInUserId;
      const messageClass = isMine ? 'mine' : 'others';

      return `
        <div class="message-box ${messageClass}">
          <div>
            <div class="sender-name">${this.formatSender(msg.sender_id, isMine)}</div>
            <div class="message-content">
              ${msg.content}
            </div>
          </div>
        </div>
      `;
    }).join('');

    this.messagesContainer.innerHTML = messagesHTML;
    this.scrollToBottom();
  },

  renderMessage(msg) {
    const loggedInUserId = document.body.dataset.userId;
    const isMine = msg.sender_id.toString() === loggedInUserId;
    const messageClass = isMine ? 'mine' : 'others';

    let template = `
      <div class="message-box ${messageClass}">
        <div>
          <div class="sender-name">${this.formatSender(msg.sender_id, isMine)}</div>
          <div class="message-content">
            ${msg.content}
          </div>
        </div>
      </div>
    `;

    this.messagesContainer.insertAdjacentHTML('beforeend', template);
    this.scrollToBottom();
  },

  formatSender(senderId, isMine) {
    if (isMine) {
      return "You";
    }
    // 실제 애플리케이션에서는 senderId를 사용해 사용자 이름을 조회해야 합니다.
    // 여기서는 예시로 "User" + ID를 사용합니다.
    return `User ${senderId}`;
  },

  scrollToBottom() {
    this.messagesContainer.scrollTop = this.messagesContainer.scrollHeight;
  },

  // ... (다른 함수들은 변경 없음)
}

export default Chat;