import { Socket } from "phoenix"
// lobby.js (카카오톡 스타일 채팅 UI)
document.addEventListener("DOMContentLoaded", () => {
    const params = new URLSearchParams(window.location.search);
    const userId = parseInt(params.get("userId"));
    if (!userId) {
        alert("❗ URL에 userId 쿼리 파라미터가 필요합니다. 예: /lobby?userId=1");
        return;
    }

    const socket = new Socket("/socket", { params: { user_id: userId } });
    socket.connect();

    const lobbyChannel = socket.channel(`user_lobby:${userId}`, {});
    const roomList = document.getElementById("user-room-list");
    const chatLobby = document.getElementById("chat-lobby");
    const chatRoom = document.getElementById("chat-room");
    const roomTitle = document.getElementById("room-title");
    const messagesContainer = document.getElementById("messages");
    const input = document.getElementById("message-input");
    const sendButton = document.getElementById("send-button");
    const backButton = document.getElementById("back-button");

    let talkChannel = null;

    lobbyChannel.join()
        .receive("ok", () => console.log("✅ 유저 로비 접속 성공"))
        .receive("error", () => console.error("❌ 로비 채널 접속 실패"));

    lobbyChannel.on("room_list", payload => {
        roomList.innerHTML = "";
        payload.rooms.forEach(room => {
            const div = document.createElement("div");
            div.className = "chat-room-item";
            div.innerHTML = `
        <div class="room-info">
          <span class="room-name">${room.name}</span>
          <span class="room-unread">${room.unread_count}</span>
        </div>
      `;
            div.addEventListener("click", () => enterRoom(room.id, room.name));
            roomList.appendChild(div);
        });
    });

    function enterRoom(roomId, roomName) {
        chatLobby.style.display = "none";
        chatRoom.style.display = "block";
        roomTitle.innerText = roomName;
        let messages = [];

        if (talkChannel) talkChannel.leave();

        talkChannel = socket.channel(`talk:${roomId}`, { user_id: userId });
        talkChannel.join()
            .receive("ok", () => {
                console.log(`✅ 채팅방 ${roomId} 입장 성공`);
                talkChannel.push("fetch_messages", {});
            })
            .receive("error", () => console.error("❌ 채팅방 입장 실패"));

        talkChannel.on("messages", payload => {
            const newMessages = payload.messages;
            messages = newMessages;
            messagesContainer.innerHTML = "";

            newMessages.forEach(msg => {
                appendMessage(msg, msg.sender_id === userId);
            });
        });

        talkChannel.on("new_msg", msg => {
            appendMessage(msg, msg.sender_id === userId);
        });

        talkChannel.on("messages:prepend", payload => {
            const scrollPos = messagesContainer.scrollHeight;

            payload.messages.forEach(msg => {
                // 중복 메시지 방지: 이미 message_id가 있으면 건너뜀
                if (messages.some(m => m.message_id === msg.message_id)) return;

                messages.unshift(msg);

                const div = document.createElement("div");
                div.className = msg.sender_id === userId ? "message mine" : "message other";
                div.innerHTML = `<div class="bubble">${msg.message}</div>`;
                messagesContainer.prepend(div);
            });

            messagesContainer.scrollTop = messagesContainer.scrollHeight - scrollPos;
        });

        // 맨 위로 스크롤했을 때 과거 메시지 로딩
        messagesContainer.addEventListener("scroll", () => {
            if (messagesContainer.scrollTop === 0 && messages.length > 0) {
                const lastKey = messages[0].message_id;
                talkChannel.push("load_more", { last_seen_key: lastKey });
            }
        });
    }

    function appendMessage(msg, isMine) {
        const div = document.createElement("div");
        div.className = isMine ? "message mine" : "message other";
        div.innerHTML = `
      <div class="bubble">
        ${msg.message}
      </div>
    `;
        messagesContainer.appendChild(div);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }

    sendButton.addEventListener("click", sendMessage);
    input.addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
            sendMessage();
        }
    });

    function sendMessage() {
        const message = input.value.trim();
        if (!message || !talkChannel) return;

        talkChannel.push("new_msg", {
            user: userId,
            message: message
        });
        input.value = "";
    }

    backButton.addEventListener("click", () => {
        if (talkChannel) talkChannel.leave();
        chatRoom.style.display = "none";
        chatLobby.style.display = "block";
    });

});