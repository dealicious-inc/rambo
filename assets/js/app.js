import { channel } from "./socket.js";

channel.join()
    .receive("ok", resp => console.log("✅ Joined", resp))
    .receive("error", err => console.error("❌ Failed", err));

channel.on("new_msg", payload => {
    const li = document.createElement("li");
    li.textContent = `${payload.user}: ${payload.message}`;
    document.getElementById("messages").appendChild(li);
});

document.getElementById("send-button").addEventListener("click", () => {
    const input = document.getElementById("chat-input");
    const message = input.value.trim();
    if (message) {
        channel.push("new_msg", { user: "alice", message });
        input.value = "";
    }
});

document.getElementById("chat-input").addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
        const input = document.getElementById("chat-input");
        const message = input.value.trim();
        if (message) {
            channel.push("new_msg", { user: "alice", message });
            input.value = "";
        }
    }
});