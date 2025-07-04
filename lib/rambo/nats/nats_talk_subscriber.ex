defmodule Rambo.Nats.TalkSubscriber do
  use GenServer
  require Logger

  @topic_pattern "talk.room.*"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    Logger.info("[TalkSubscriber] NATS 토픽 구독 시작: #{@topic_pattern}")

    case Gnat.sub(:gnat, self(), @topic_pattern) do
      {:ok, _sid} ->
        Logger.info("[TalkSubscriber] 구독 성공")
        {:ok, Map.put(state, :subscribed, true)}

      {:error, reason} ->
        Logger.error("[TalkSubscriber] 구독 실패: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    Logger.debug("[TalkSubscriber] 메시지 수신: #{msg.topic} → #{msg.body}")

    case handle_jetstream_message(msg) do
      :ok ->
        Jetstream.ack(msg)
        Logger.debug("[TalkSubscriber] ack 처리 완료")

      :skip ->
        Jetstream.ack_term(msg)
        Logger.debug("[TalkSubscriber] 유저 없음 → ack_term 처리")

      :retry ->
        Jetstream.nack(msg)
        Logger.warning("[TalkSubscriber] 메시지 처리 실패 → nack 재전송 요청")
    end

    {:noreply, state}
  end

  defp handle_jetstream_message(%{topic: topic, body: raw}) do
    with {:ok, payload} <- Jason.decode(raw),
         room_id <- extract_room_id(topic),
         true <- valid_room_id?(room_id) do

      if room_open?(room_id) do
        RamboWeb.Endpoint.broadcast!("talk:#{room_id}", "new_msg", payload)
        :ok
      else
        Logger.info("[TalkSubscriber] talk:#{room_id}에 접속 중인 유저가 없어 메시지 전송 생략")
        :skip
      end
    else
      {:error, reason} ->
        Logger.error("[TalkSubscriber] JSON 파싱 실패: #{inspect(reason)}")
        :retry

      false ->
        Logger.warn("[TalkSubscriber] 유효하지 않은 토픽 형식: #{topic}")
        :skip
    end
  end

  defp extract_room_id("talk." <> room_id), do: room_id
  defp extract_room_id(_), do: nil
  defp valid_room_id?(room_id), do: room_id != nil and room_id != ""

  defp room_open?(room_id) do
    true
    # TODO 유저가 참여한 경우에만 브로드캐스트 하도록 변경 필요 Presence사용 예정
    # "talk:#{room_id}"
    # |> Phoenix.PubSub.subscribers(Rambo.PubSub)
    # |> Enum.any?()
  end
end
