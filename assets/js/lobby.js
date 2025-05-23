import { Socket } from "phoenix"

// lobby.js (프론트에서 참여 중인 채팅방 목록 + 채팅방 입장)
document.addEventListener("DOMContentLoaded", () => {
    const userId = 1; // 유저 ID는 실제 로그인 정보에서 가져오도록 할 수 있음
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
            const msgContainer = document.getElementById("messages");
            msgContainer.innerHTML = "";
            payload.messages.slice().reverse().forEach(msg => {
                const div = document.createElement("div");
                div.innerText = `[${msg.sender_id}] ${msg.message}`;
                msgContainer.appendChild(div);
            });
        });

        talkChannel.on("new_msg", msg => {
            const div = document.createElement("div");
            div.innerText = `[${msg.sender_id}] ${msg.message}`;
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