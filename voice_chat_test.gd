extends Control

@onready var remote_audio := $RemoteAudioStreamPlayer
var opus: AudioEffectOpusChunked

var received_packets: Array[PackedByteArray] = []

var _connected := false


func _ready() -> void:
	%JoinButton.pressed.connect(func():
		var peer = ENetMultiplayerPeer.new()
		var err := peer.create_client(
			%IpEdit.text if %IpEdit.text else "127.0.0.1",
			50000
		)
		if err:
			push_error(err)
		multiplayer.multiplayer_peer = peer
		multiplayer.connected_to_server.connect(func():
			multiplayer.multiplayer_peer = peer
			_connected = true
			push_warning("Joined")
			%Host.hide()
		)
		multiplayer.connection_failed.connect(func():
			push_error("Failed to join server")
		)
	)
	%HostButton.pressed.connect(func():
		var peer = ENetMultiplayerPeer.new()
		peer.create_server(50000)
		multiplayer.multiplayer_peer = peer
		_connected = true
		push_warning("Hosted")
		%Join.hide()
	)
	var microphone_id := AudioServer.get_bus_index("Microphone")
	opus = AudioServer.get_bus_effect(microphone_id, 0)


func _process(delta: float) -> void:
	if not _connected:
		return
	# Send
	var prepend = PackedByteArray()
	while opus.chunk_available():
		var opus_packet: PackedByteArray = opus.read_opus_packet(prepend)
		opus.drop_chunk()
		#push_warning("Transmitted packet!")
		transmit.rpc(opus_packet)
	# receive
	var remote_opus_stream := remote_audio.stream as AudioStreamOpusChunked
	while not received_packets.is_empty() and remote_opus_stream.chunk_space_available():
		var packet: PackedByteArray = received_packets.pop_front()
		remote_opus_stream.push_opus_packet(packet, 0, 0)
		#push_warning("received packet %s. Processing..." % packet.size())
	#if received_packets:
		#push_warning("Received packets has values though they should be ")


@rpc("any_peer", "call_remote")
func transmit(packet: PackedByteArray) -> void:
	#push_warning("Received packet from transmit")
	received_packets.append(packet)
	
