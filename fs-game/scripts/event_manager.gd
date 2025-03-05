extends Node

# Identifiants de session et utilisateur (à adapter selon vos besoins)
var session_id = 2
var user_id = 3

var service_url = "http://localhost:3000/events"

func _ready():
    print("EventManager prêt")

# Fonction générique pour envoyer un événement
func send_event(event_type: String, metadata: Dictionary) -> void:
    var http_request = HTTPRequest.new()
    add_child(http_request)  # Le nœud doit être dans la scène pour fonctionner
    
    var event_data = {
        "session_id": session_id,
        "event_type": event_type,
        "event_timestamp": OS.get_unix_time(),
        "metadata": metadata,
        "user_id": user_id
    }
    
    var json_payload = to_json(event_data)
    var headers = ["Content-Type: application/json"]
    
    var err = http_request.request(service_url, headers, true, HTTPClient.METHOD_POST, json_payload)
    if err != OK:
        print("Erreur lors de l'envoi de l'événement: ", err)
    else:
        print("Événement envoyé: ", event_data)
