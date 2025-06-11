import { Socket } from "phoenix"

// lobby.js (프론트에서 참여 중인 채팅방 목록 + 채팅방 입장)
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
    lobbyChannel.join()
        .receive("ok", () => console.log("✅ 유저 로비 접속 성공"))
        .receive("error", () => console.error("❌ 로비 채널 접속 실패"));

    const roomList = document.getElementById("user-room-list");
    lobbyChannel.on("room_list", payload => {
        roomList.innerHTML = "";
        payload.rooms.forEach(room => {
            const li = document.createElement("li");
            li.textContent = `${room.name} (${room.unread_count} 안읽음)`;
            li.addEventListener("click", () => enterRoom(room.id, room.name));
            roomList.appendChild(li);
        });
    });

    let talkChannel = null;
    function enterRoom(roomId, roomName) {
        document.getElementById("chat-lobby").style.display = "none";
        document.getElementById("chat-room").style.display = "block";
        document.getElementById("room-title").innerText = roomName;

        if (talkChannel) talkChannel.leave();

        talkChannel = socket.channel(`talk:${roomId}`, { user_id: userId });
        talkChannel.join()
            .receive("ok", () => {
                console.log(`✅ 채팅방 ${roomId} 입장 성공`);
                talkChannel.push("fetch_messages", {});
            })
            .receive("error", () => console.error("❌ 채팅방 입장 실패"));

        talkChannel.on("messages", payload => {
            console.log(`"Asdad" ${payload.messages}`);
            const msgContainer = document.getElementById("messages");
            msgContainer.innerHTML = "";
            payload.messages.slice().reverse().forEach(msg => {
                const div = document.createElement("div");
                div.innerText = `[${msg.sender_id}] ${msg.content}`;
                msgContainer.appendChild(div);
            });
        });

        talkChannel.on("new_msg", msg => {
            const div = document.createElement("div");
            div.innerText = `[${msg.sender_id}] ${msg.content}`;
            document.getElementById("messages").appendChild(div);
        });
    }

    document.getElementById("send-button").addEventListener("click", sendMessage);

    document.getElementById("message-input").addEventListener("keydown", function (event) {
        if (event.key === "Enter") {
            sendMessage();
        }
    });

    function sendMessage() {
        const input = document.getElementById("message-input");
        const message = input.value.trim();
        if (!message) return;

        talkChannel.push("new_msg", {
            user: userId,
            message: message
        });

        input.value = "";
    }
});

let Lobby = {
  init(socket) {
    // ... (init 함수 윗부분은 변경 없음)
  },

  renderRooms(rooms) {
    if (rooms.length === 0) {
      this.roomList.innerHTML = '<p>현재 열려있는 채팅방이 없습니다. 새 방을 만들어보세요!</p>';
      return;
    }

    let roomLinks = rooms.map(room => {
      return `
        <li>
          <span class="room-name">${room.name}</span>
          <a href="/chat?room_id=${room.id}" class="join-button">입장</a>
        </li>
      `;
    }).join('');

    this.roomList.innerHTML = roomLinks;
  }
};

export default Lobby;