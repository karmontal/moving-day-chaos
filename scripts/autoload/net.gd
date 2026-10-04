extends Node
## Online session (Phase 2): ENet host/join, LAN discovery, and internet play through our noray
## server (room codes, NAT punch-through with relay fallback, see scripts/net/noray_client.gd). The host is authoritative: it runs
## all physics and streams snapshots; clients only send their MoverInput (see Mission).
## Swapping ENetMultiplayerPeer for SteamMultiplayerPeer later keeps everything else the same.

signal players_changed
signal session_started(mission_id: String)
signal session_ended(reason: String)
signal hosts_changed
signal status_changed(text: String)

const PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_PLAYERS := 4
const DISCOVERY_INTERVAL := 1.0
const HOST_TIMEOUT := 3.5

## peer_id -> {"name": String, "character": int, "upgrades": {upgrade id: level}}
var players := {}
## ip -> {"name": String, "players": int, "seen": float}
var found_hosts := {}
var active := false
var in_game := false
## Why the last session ended (shown by the lobby), cleared once shown.
var last_error := ""
## Internet play: the room code friends type in (noray open id), empty on LAN.
var room_code := ""
## Job chosen by the host for the current session.
var mission_id := "starter_apartment"
var noray := NorayClient.new()
var _join_code := ""
var _tried_relay := false
## Tests: skip the NAT punch and go straight through the relay.
var force_relay := false

var _broadcast: PacketPeerUDP = null
var _listen: PacketPeerUDP = null
var _broadcast_timer := 0.0


func _ready() -> void:
	add_child(noray)
	noray.connect_nat.connect(_on_noray_connect.bind(false))
	noray.connect_relay.connect(_on_noray_connect.bind(true))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(func() -> void: _end("NET_HOST_LEFT"))


func is_host() -> bool:
	return active and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


func host() -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	players = {1: {"name": Settings.player_name, "character": Settings.character, "upgrades": Progress.upgrades.duplicate()}}
	_broadcast = PacketPeerUDP.new()
	_broadcast.set_broadcast_enabled(true)
	_broadcast.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	players_changed.emit()
	return OK


func join(ip: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	return OK


func leave() -> void:
	if active:
		multiplayer.multiplayer_peer.close()
	noray.disconnect_from_host()
	room_code = ""
	_join_code = ""
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	in_game = false
	players.clear()
	_broadcast = null
	players_changed.emit()


func online_available() -> bool:
	return str(Data.online.get("noray_host", "")) != ""


## Internet host: register with noray, listen on the registered port, publish the room code.
func host_online() -> Error:
	leave()
	var err := await _register_with_noray()
	if err != OK:
		return err
	var peer := ENetMultiplayerPeer.new()
	err = peer.create_server(noray.local_port, MAX_PLAYERS - 1)
	if err != OK:
		noray.disconnect_from_host()
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	room_code = noray.oid
	players = {1: {"name": Settings.player_name, "character": Settings.character, "upgrades": Progress.upgrades.duplicate()}}
	players_changed.emit()
	return OK


## Internet client: ask noray to connect us to the room (NAT punch first, relay as fallback).
func join_code(code: String) -> Error:
	leave()
	code = code.strip_edges().to_upper()
	if code.length() < 4:
		return ERR_INVALID_PARAMETER
	status_changed.emit("NET_CONNECTING")
	var err := await _register_with_noray()
	if err != OK:
		return err
	_join_code = code
	_tried_relay = force_relay
	return noray.request_relay(code) if force_relay else noray.request_nat(code)


func _register_with_noray() -> Error:
	var cfg := Data.online
	var err := await noray.connect_to_host(str(cfg.noray_host), int(cfg.get("noray_port", 8890)))
	if err != OK:
		return err
	noray.register_host()
	var end := Time.get_ticks_msec() + 6000
	while noray.pid == "" and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	if noray.pid == "":
		noray.disconnect_from_host()
		return ERR_TIMEOUT
	err = await noray.register_remote(int(cfg.get("registrar_port", 8809)))
	if err != OK:
		noray.disconnect_from_host()
	return err


func _on_noray_connect(address: String, port: int, relay: bool) -> void:
	if is_host():
		# Someone is joining: punch towards them from our listening socket.
		await NorayClient.handshake_from_host(get_tree(), multiplayer.multiplayer_peer as ENetMultiplayerPeer, address, port)
		return
	if _join_code == "" or active:
		return
	var udp := PacketPeerUDP.new()
	udp.bind(noray.local_port)
	udp.set_dest_address(address, port)
	var err := await NorayClient.handshake(get_tree(), udp)
	udp.close()
	if err != OK and err != ERR_BUSY:
		_try_relay()
		return
	var peer := ENetMultiplayerPeer.new()
	err = peer.create_client(address, port, 0, 0, 0, noray.local_port)
	if err != OK:
		_try_relay()
		return
	multiplayer.multiplayer_peer = peer
	active = true


func _try_relay() -> void:
	if _tried_relay or _join_code == "":
		_end("NET_FAILED")
		return
	_tried_relay = true
	status_changed.emit("NET_RELAY")
	if active:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		active = false
	noray.request_relay(_join_code)


func _on_connection_failed() -> void:
	if _join_code != "" and not _tried_relay:
		_try_relay()
	else:
		_end("NET_FAILED")


## Starts listening for hosts on the local network (lobby "Join" screen).
func start_discovery() -> void:
	if _listen:
		return
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISCOVERY_PORT) != OK:
		_listen = null


func stop_discovery() -> void:
	if _listen:
		_listen.close()
	_listen = null
	found_hosts.clear()


func set_character(c: int) -> void:
	Settings.set_value("character", c)
	if not active:
		return
	if is_host():
		_claim(1, Settings.player_name, c, Progress.upgrades)
	else:
		_register.rpc_id(1, Settings.player_name, c, Progress.upgrades)


func taken_characters(except_peer := -1) -> Array[int]:
	var out: Array[int] = []
	for id: int in players:
		if id != except_peer:
			out.append(int(players[id].character))
	return out


## Host only: everyone loads the mission.
func start_game(mission_id := "starter_apartment") -> void:
	if is_host():
		_start.rpc(mission_id)


## Sorted peer ids, the same order on every machine (used to spawn movers deterministically).
func peer_order() -> Array[int]:
	var ids: Array[int] = []
	for id: int in players:
		ids.append(id)
	ids.sort()
	return ids


static func local_ips() -> Array[String]:
	var out: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and not ip.begins_with("172.17.")):
			out.append(ip)
	return out


func _process(delta: float) -> void:
	if _broadcast and not in_game:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = DISCOVERY_INTERVAL
			var msg := JSON.stringify({"game": "mdc", "v": 1, "name": Settings.player_name, "players": players.size()})
			_broadcast.put_packet(msg.to_utf8_buffer())
	if _listen:
		var now := Time.get_ticks_msec() / 1000.0
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var pkt := _listen.get_packet().get_string_from_utf8()
			var ip := _listen.get_packet_ip()
			var d: Variant = JSON.parse_string(pkt)
			if d is Dictionary and d.get("game") == "mdc":
				changed = changed or not found_hosts.has(ip)
				found_hosts[ip] = {"name": str(d.get("name", "?")), "players": int(d.get("players", 1)), "seen": now}
		for ip: String in found_hosts.keys():
			if now - float(found_hosts[ip].seen) > HOST_TIMEOUT:
				found_hosts.erase(ip)
				changed = true
		if changed:
			hosts_changed.emit()


func _on_connected() -> void:
	_register.rpc_id(1, Settings.player_name, Settings.character, Progress.upgrades)


func _on_peer_connected(_id: int) -> void:
	pass  # the client registers itself right after connecting


func _on_peer_disconnected(id: int) -> void:
	if is_host() and players.has(id):
		players.erase(id)
		_sync_players.rpc(players)
		players_changed.emit()


@rpc("any_peer", "reliable")
func _register(player_name: String, character: int, upgrades: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game:
		# No joining mid-job in this version.
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	_claim(id, player_name, character, upgrades)


## Host: records a player's choice, bumping them to a free character if it is taken.
func _claim(id: int, player_name: String, character: int, upgrades := {}) -> void:
	var taken := taken_characters(id)
	var c := clampi(character, 0, Palette.PLAYER_COLORS.size() - 1)
	while c in taken:
		c = (c + 1) % Palette.PLAYER_COLORS.size()
	players[id] = {"name": player_name.left(16), "character": c, "upgrades": Progress.clean_levels(upgrades)}
	_sync_players.rpc(players)
	players_changed.emit()


@rpc("authority", "reliable")
func _sync_players(list: Dictionary) -> void:
	players = list
	var me: Variant = players.get(my_id())
	if me != null:
		# Not saved: only an explicit pick in the lobby persists the choice.
		Settings.character = int(me.character)
	players_changed.emit()


@rpc("authority", "reliable", "call_local")
func _start(id: String) -> void:
	mission_id = id if Data.missions.has(id) else "starter_apartment"
	in_game = true
	session_started.emit(id)
	get_tree().change_scene_to_file("res://scenes/mission.tscn")


func _end(reason: String) -> void:
	var was_active := active
	last_error = reason
	leave()
	if was_active:
		session_ended.emit(reason)
