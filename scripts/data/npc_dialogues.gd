# =============================================================================
# NPC DIALOGUE DATA - Cyber Security Lessons
# =============================================================================
# Contains dialogue scripts for different NPCs teaching about cyber attacks
# Path: res://scripts/data/npc_dialogues.gd
# =============================================================================

class_name NPCDialogues

# Different lesson topics for NPCs
enum LessonType {
	PHISHING,
	PASSWORD_SECURITY,
	SOCIAL_ENGINEERING,
	MALWARE,
	PUBLIC_WIFI
}

static func get_dialogue(lesson_type: LessonType, player_name: String = "You") -> Array[Dictionary]:
	match lesson_type:
		LessonType.PHISHING:
			return _get_phishing_dialogue(player_name)
		LessonType.PASSWORD_SECURITY:
			return _get_password_dialogue(player_name)
		LessonType.SOCIAL_ENGINEERING:
			return _get_social_engineering_dialogue(player_name)
		LessonType.MALWARE:
			return _get_malware_dialogue(player_name)
		LessonType.PUBLIC_WIFI:
			return _get_public_wifi_dialogue(player_name)
	return []


static func _get_phishing_dialogue(player_name: String) -> Array[Dictionary]:
	return [
		{"speaker": player_name, "text": "Hey... I think I almost got scammed. Someone sent me a message saying I won 20 million!", "is_player": true},
		{"speaker": "Cyber Expert", "text": "That's a phishing attack! Scammers pretend to be trustworthy to steal your info. They use urgency, fake rewards, or fear to trick you.", "is_player": false},
		{"speaker": player_name, "text": "How can I protect myself?", "is_player": true},
		{"speaker": "Cyber Expert", "text": "Never share passwords via message. Check the sender. If it's too good to be true, it's fake! Stay safe! 🛡️", "is_player": false},
	]


static func _get_password_dialogue(player_name: String) -> Array[Dictionary]:
	return [
		{"speaker": player_name, "text": "Hi! I use the same password everywhere... is that bad?", "is_player": true},
		{"speaker": "Security Expert", "text": "Very bad! If one account gets hacked, ALL your accounts are at risk. Hackers try stolen passwords everywhere!", "is_player": false},
		{"speaker": player_name, "text": "What should I do then?", "is_player": true},
		{"speaker": "Security Expert", "text": "Use 12+ characters with symbols, a password manager, and enable 2FA - it requires your phone even if password leaks! 🔐", "is_player": false},
	]


static func _get_social_engineering_dialogue(player_name: String) -> Array[Dictionary]:
	return [
		{"speaker": player_name, "text": "Someone called saying they're from my bank. They knew my name!", "is_player": true},
		{"speaker": "Privacy Expert", "text": "That's Social Engineering! They manipulate you using public info from social media. Vishing, smishing, pretexting - many tricks!", "is_player": false},
		{"speaker": player_name, "text": "How do I know if it's real?", "is_player": true},
		{"speaker": "Privacy Expert", "text": "Banks NEVER ask for passwords by phone! Hang up and call their official number. Trust your gut! 🦸", "is_player": false},
	]


static func _get_malware_dialogue(player_name: String) -> Array[Dictionary]:
	return [
		{"speaker": player_name, "text": "My friend's computer got infected. What's malware?", "is_player": true},
		{"speaker": "Tech Expert", "text": "Malware is malicious software! Viruses spread via files, trojans hide in fake apps, ransomware locks your data for money!", "is_player": false},
		{"speaker": player_name, "text": "How do I stay protected?", "is_player": true},
		{"speaker": "Tech Expert", "text": "Keep systems updated, use antivirus, only download from official stores, and backup your files regularly! 💪", "is_player": false},
	]


static func _get_public_wifi_dialogue(player_name: String) -> Array[Dictionary]:
	return [
		{"speaker": player_name, "text": "I love using free WiFi at cafes. Is that safe?", "is_player": true},
		{"speaker": "Network Expert", "text": "Dangerous! Public WiFi is often unencrypted. Hackers can intercept your data, create fake networks, or inject malware!", "is_player": false},
		{"speaker": player_name, "text": "But I need WiFi when I'm out!", "is_player": true},
		{"speaker": "Network Expert", "text": "Use a VPN to encrypt your connection, only visit HTTPS sites, and never do banking on public WiFi. Use mobile data for sensitive tasks! 🔐", "is_player": false},
	]
