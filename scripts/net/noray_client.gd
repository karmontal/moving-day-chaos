class_name NorayClient
extends Node
## Minimal client for noray (https://github.com/foxssake/noray), the connection orchestrator
## running on our VPS. Adapted from netfox.noray (MIT, (c) 2023 Gálffy Tamás — see
## NORAY_CLIENT_LICENSE.txt) without the netfox dependencies.
##
## Flow: connect over TCP -> "register-host" (server answers set-oid / set-pid) -> register our
## external UDP port by sending the pid to the registrar -> host listens on that port; clients ask
## "connect <oid>" (NAT punch) or "connect-relay <oid>" and both sides shake hands over UDP.

signal command_received(command: String, data: String)
signal oid_received(oid: String)
signal pid_received(pid: String)
signal connect_nat(address: String, port: int)
signal connect_relay(address: String, port: int)

var oid := ""
var pid := ""
## The UDP port registered with noray; the host listens on it and clients bind to it.
var local_port := -1

var _peer := StreamPeerTCP.new()
var _address := ""
var _buffer := ""


func connect_to_host(address: String, port: int, timeout := 6.0) -> Error:
	disconnect_from_host()
	_address = IP.resolve_hostname(address, IP.TYPE_IPV4)
	if _address == "":
		return ERR_CANT_RESOLVE
	var err := _peer.connect_to_host(_address, port)
	if err != OK:
		return err
	_peer.set_no_delay(true)
	_buffer = ""
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while _peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() < end:
		_peer.poll()
		await get_tree().process_frame
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		disconnect_from_host()
		return ERR_CANT_CONNECT
	return OK


func is_connected_to_host() -> bool:
	return _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED


func disconnect_from_host() -> void:
	_peer.disconnect_from_host()
	oid = ""
	pid = ""
	local_port = -1


## Asks for an open id (room code) and private id.
func register_host() -> Error:
	return _send("register-host")


## Tells noray which external UDP port we are reachable on.
func register_remote(registrar_port: int, timeout := 8.0) -> Error:
	if pid == "":
		return ERR_UNAUTHORIZED
	var udp := PacketPeerUDP.new()
	udp.bind(0)
	udp.set_dest_address(_address, registrar_port)
	var packet := pid.to_utf8_buffer()
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	var result := ERR_TIMEOUT
	while Time.get_ticks_msec() < end and result == ERR_TIMEOUT:
		udp.put_packet(packet)
		await get_tree().create_timer(0.1).timeout
		while udp.get_available_packet_count() > 0:
			result = OK if udp.get_packet().get_string_from_utf8() == "OK" else FAILED
	if result == OK:
		local_port = udp.get_local_port()
	udp.close()
	return result


func request_nat(host_oid: String) -> Error:
	return _send("connect " + host_oid)


func request_relay(host_oid: String) -> Error:
	return _send("connect-relay " + host_oid)


func _process(_delta: float) -> void:
	if not is_connected_to_host():
		return
	_peer.poll()
	var available := _peer.get_available_bytes()
	if available <= 0:
		return
	_buffer += _peer.get_utf8_string(available)
	while _buffer.contains("\n"):
		var line := _buffer.get_slice("\n", 0).strip_edges()
		_buffer = _buffer.substr(_buffer.find("\n") + 1)
		if line != "":
			_handle(line.get_slice(" ", 0), line.get_slice(" ", 1) if line.contains(" ") else "")


func _handle(command: String, data: String) -> void:
	command_received.emit(command, data)
	match command:
		"set-oid":
			oid = data
			oid_received.emit(data)
		"set-pid":
			pid = data
			pid_received.emit(data)
		"connect":
			connect_nat.emit(data.get_slice(":", 0), data.get_slice(":", 1).to_int())
		"connect-relay":
			connect_relay.emit(_address, data.to_int())


func _send(line: String) -> Error:
	if not is_connected_to_host():
		return ERR_CONNECTION_ERROR
	return _peer.put_data((line + "\n").to_utf8_buffer())


## UDP handshake used by both sides before ENet connects (punches the NAT open).
## Returns OK, or ERR_BUSY when we heard them but could not confirm (still worth trying).
static func handshake(tree: SceneTree, peer: PacketPeerUDP, timeout := 8.0) -> Error:
	var did_read := false
	var did_handshake := false
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < end:
		while peer.get_available_packet_count() > 0:
			var status := peer.get_packet().get_string_from_ascii()
			did_read = true
			if status.contains("r"):
				did_handshake = true
			if status.contains("x") and did_handshake:
				return OK
		var mine := "$" + ("r" if did_read else "-") + "w" + ("x" if did_handshake else "-")
		peer.put_packet(mine.to_ascii_buffer())
		await tree.create_timer(0.1).timeout
	return ERR_BUSY if did_read else ERR_TIMEOUT


## Host side: we cannot read through ENet's socket, so just keep announcing a finished handshake.
static func handshake_from_host(tree: SceneTree, enet: ENetMultiplayerPeer, address: String, port: int, timeout := 8.0) -> Error:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < end:
		if enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return ERR_CONNECTION_ERROR
		enet.host.socket_send(address, port, "$rwx".to_ascii_buffer())
		await tree.create_timer(0.1).timeout
	return OK
