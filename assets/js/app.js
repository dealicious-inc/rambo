import {Socket} from "phoenix"

// 1. 소켓 연결
const socket = new Socket("/socket", {params: {userToken: "123"}})
socket.connect()

// 2. 채널 참여 (예: room:1)
const channel = socket.channel("room:1", {})

// 3. 채널 join
channel.join()
    .receive("ok", resp => {
        console.log("✅ Joined successfully", resp)
    })
    .receive("error", resp => {
        console.error("❌ Unable to join", resp)
    })

// 4. 서버에서 오는 메시지 수신
channel.on("new_msg", payload => {
    console.log(`[RECEIVED] ${payload.user}: ${payload.message}`)
})

if (document.getElementById("messages")) {
    channel.on("new_msg", (payload) => {
        const messageList = document.getElementById("messages");
        const li = document.createElement("li");
        li.textContent = `${payload.user}: ${payload.message}`;
        messageList.appendChild(li);
    });
}

