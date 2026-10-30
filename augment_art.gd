extends RefCounted

const Catalog = preload("res://augments.gd")
static var cache = {}

static func texture_for(id: String) -> Texture2D:
	if cache.has(id):
		return cache[id]
	if id == "domain":
		cache[id] = load("res://assets/domain_gojo_official.jpg")
		return cache[id]
	var image = Image.new()
	if id != "domain":
		var kind = Catalog.ALL[id]["kind"]
		var colors = {"active": ["#122c54", "#337dc5"], "passive": ["#193b36", "#50a985"], "debuff": ["#482638", "#bd6378"]}[kind]
		var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect width="128" height="128" rx="12" fill="%s"/><rect x="5" y="5" width="118" height="118" rx="9" fill="none" stroke="%s" stroke-width="2"/><g stroke="#eef5ff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" fill="none">%s</g></svg>' % [colors[0], colors[1], _body(id)]
		image.load_svg_from_string(svg)
	if image == null or image.is_empty():
		push_error("Missing augment artwork: " + id)
		return null
	cache[id] = ImageTexture.create_from_image(image)
	return cache[id]

static func _body(id: String) -> String:
	var drawings = {
		"vitality": '<path d="M64 101L25 62Q10 35 34 26Q52 20 64 40Q76 20 94 26Q118 35 103 62Z" fill="#e77b98"/><path d="M64 43V79M46 61H82" stroke="#fff2c4" stroke-width="9"/>',
		"blood_trade": '<path d="M43 20Q8 60 22 77Q43 96 64 77Q78 60 43 20Z" fill="#dd647b"/><circle cx="87" cy="86" r="24" fill="#efc257"/><path d="M87 72V100M77 86H97" stroke="#825922"/>',
		"insurance": '<path d="M64 20L104 36V66Q95 95 64 111Q33 95 24 66V36Z" fill="#5a9dbb"/><path d="M64 43V82M46 63H82" stroke="#ffe3a5" stroke-width="9"/>',
		"heart": '<path d="M64 104L26 67Q8 39 33 27Q51 18 64 42Q77 18 95 27Q120 39 102 67Z" fill="#d66e8a"/><path d="M64 86V47M48 63L64 47L80 63" stroke="#ffe7a8" stroke-width="8"/>',
		"medic": '<rect x="21" y="38" width="86" height="67" rx="10" fill="#ddc9a0"/><path d="M46 38V23H82V38M64 52V89M46 71H82" stroke="#ba5d70" stroke-width="10"/>',
		"reserve": '<path d="M23 57Q25 35 61 35Q91 35 101 59L113 61V79L100 83L94 103H80V90H45V103H31L29 83L17 77V60Z" fill="#e6b0a1"/><path d="M48 35L59 22L70 35M48 48H76"/><circle cx="91" cy="59" r="3" fill="#20344b"/>',
		"healing_loss": '<path d="M64 103L28 69Q9 44 32 30Q52 18 64 43Q76 18 96 30Q119 44 100 69Z" fill="#b16d8d"/><path d="M43 65H85" stroke="#ffd3a3" stroke-width="10"/><path d="M21 108L108 21" stroke="#e6b4c8"/>',
		"settlement_fee": '<path d="M28 19H99V109L87 101L75 109L63 101L51 109L39 101L28 109Z" fill="#9b8198"/><path d="M43 40H83M43 57H83M43 74H62"/><circle cx="89" cy="90" r="19" fill="#e9b966"/><path d="M79 90H99" stroke="#93576a"/>',
		"hound": '<path d="M34 46L20 26L23 75L37 78M94 46L108 26L105 75L91 78" fill="#aa7546"/><path d="M34 38Q64 24 94 38L91 89Q64 111 37 89Z" fill="#dfac67"/><ellipse cx="64" cy="78" rx="24" ry="18" fill="#f9deb3"/><circle cx="48" cy="57" r="4" fill="#101e35" stroke="none"/><circle cx="80" cy="57" r="4" fill="#101e35" stroke="none"/><path d="M55 73L73 73L64 83Z" fill="#101e35"/><path d="M64 83V94"/>',
		"scanner": '<circle cx="64" cy="64" r="40"/><circle cx="64" cy="64" r="25" stroke="#6ce8b2"/><path d="M64 24V64L95 38" stroke="#6ce8b2"/><path d="M64 64L94 38L104 64Z" fill="#255c6c" stroke="none"/><circle cx="45" cy="81" r="5" fill="#79ffb4"/><circle cx="83" cy="52" r="5" fill="#79ffb4"/>',
		"safe_dig": '<path d="M31 87L76 42M42 31Q75 21 100 50L89 60Q69 39 42 45Z" stroke="#8dddf2"/><path d="M37 80L37 101L53 111L69 101V80Z" fill="#47a78a"/><path d="M45 94L52 100L63 87"/>',
		"survey": '<path d="M21 65L44 32L63 52L79 25L108 65Z" fill="#88b5b1"/><path d="M21 81Q40 68 61 81T107 81M21 99Q40 86 61 99T107 99" stroke="#e9c786"/><path d="M44 32L51 44L39 44Z" fill="#f6f5ed"/>',
		"shield": '<path d="M64 20L100 34V65Q95 91 64 108Q33 91 28 65V34Z" fill="#307899"/><path d="M44 63L58 78L86 47" stroke="#8df3c4" stroke-width="8"/>',
		"transfusion": '<path d="M45 23H83M64 23V34M40 36H88V91Q64 105 40 91Z" fill="#db6376"/><path d="M64 51V77M51 64H77M64 99V113"/><path d="M96 36Q113 55 96 62Q79 55 96 36Z" fill="#f28d9c" stroke="none"/>',
		"grant": '<ellipse cx="50" cy="91" rx="29" ry="12" fill="#bd7b20"/><path d="M21 77V91M79 77V91" stroke="#f5ca68"/><ellipse cx="50" cy="77" rx="29" ry="12" fill="#f3c24c"/><ellipse cx="80" cy="59" rx="27" ry="12" fill="#d88e28"/><path d="M53 44V59M107 44V59" stroke="#f5ca68"/><ellipse cx="80" cy="44" rx="27" ry="12" fill="#ffdf6d"/><path d="M80 35V52" stroke="#a16420"/>',
		"audit": '<path d="M32 106V26L84 42L32 59" fill="#edb765"/><path d="M60 88L73 101L103 67" stroke="#7ee3aa" stroke-width="8"/>',
		"acceleration": '<path d="M28 94L74 48M41 35Q73 21 99 51L87 62Q68 44 41 48" stroke="#9ccdda"/><path d="M90 16L75 40H88L77 65L111 32H97L109 16" fill="#ffe171" stroke="none"/><path d="M20 60L35 60M15 75H27" stroke="#ffe171"/>',
		"shock": '<path d="M64 99L29 67Q12 43 32 31Q51 19 64 43Q77 19 96 31Q116 43 99 67Z" fill="#d96f8b"/><path d="M20 65H43L52 49L65 81L76 59H108" stroke="#b1f3ff"/>',
		"dividend": '<circle cx="50" cy="56" r="25" fill="#2b303c"/><path d="M50 20V30M50 82V92M14 56H24M76 56H86M24 30L32 38M69 75L78 83M25 82L33 74M68 38L77 29"/><circle cx="84" cy="88" r="22" fill="#efc753" stroke="#ffdf86"/><path d="M84 74V102M92 78H80Q73 81 84 88Q97 95 78 98" stroke="#936519" stroke-width="4"/>',
		"regeneration": '<path d="M65 104V61Q30 65 29 31Q63 30 65 61Q66 24 103 27Q101 62 65 69" fill="#5bb989"/><path d="M39 100Q64 88 90 100" stroke="#edcc90"/><path d="M35 81H53M44 72V90" stroke="#aaf7cf"/>',
		"revival": '<path d="M31 43A41 41 0 1 1 25 78M31 43V21M31 43H53" stroke="#b5e2e5" stroke-width="7"/><path d="M64 38V86M47 61H81" stroke="#ffdd8b" stroke-width="10"/>',
		"echo": '<path d="M31 97L72 48M41 35Q68 24 90 45L79 56Q60 39 41 47" stroke="#ead49b"/><path d="M79 72Q94 82 79 96M93 61Q118 82 93 108M24 29Q9 47 24 64" stroke="#86dfea"/>',
		"decontamination": '<path d="M61 24H89M65 24V48L45 88Q38 106 59 107H94Q115 106 107 88L85 48V24" fill="#63bda1"/><path d="M52 78H99M71 59H81"/><path d="M20 36L43 59M43 36L20 59" stroke="#efc295"/>',
		"armor": '<path d="M39 22L26 48L37 58V106H91V58L102 48L89 22L77 30H51Z" fill="#648ea2"/><path d="M51 30L64 48L77 30M64 48V105M39 65H89M40 85H89" stroke="#c6e2e8"/>',
		"artisan": '<path d="M33 80V24L80 39L33 56M22 104H68" fill="#71b49b"/><path d="M86 65L92 78L107 80L96 90L99 106L86 98L73 106L76 90L65 80L80 78Z" fill="#f6cc66" stroke="#ffe8a4"/><circle cx="97" cy="28" r="4" fill="#ffe8a4"/><circle cx="105" cy="48" r="3" fill="#ffe8a4"/>',
		"frugal": '<rect x="22" y="42" width="84" height="60" rx="9" fill="#8d7760"/><path d="M25 42L81 24L94 42" fill="#a7d8b2"/><path d="M84 61H107V84H84Z" fill="#e1bd76"/><circle cx="93" cy="72" r="2"/><circle cx="39" cy="73" r="4" fill="#aff2b8"/><circle cx="53" cy="73" r="4" fill="#aff2b8"/><circle cx="67" cy="73" r="4" fill="#aff2b8"/>',
		"salvage": '<path d="M29 31V66Q29 94 57 94Q85 94 85 66V31H68V66Q68 76 57 76Q46 76 46 66V31Z" fill="#c9797f"/><path d="M29 45H46M68 45H85"/><circle cx="95" cy="97" r="16" fill="#f0c35b" stroke="#ffe8a4"/><path d="M95 88V106" stroke="#996921"/>',
		"stealth": '<path d="M31 105V53Q31 19 64 19Q97 19 97 53V105L81 94L64 105L47 94Z" fill="#9681ae"/><circle cx="51" cy="57" r="5" fill="#20273f" stroke="none"/><circle cx="77" cy="57" r="5" fill="#20273f" stroke="none"/><path d="M20 111L108 20" stroke="#f2a5b1"/>',
		"high_explosive": '<path d="M64 16L74 40L98 27L87 52L113 63L88 74L101 99L76 87L64 113L52 88L27 101L40 76L15 64L40 52L29 29L53 41Z" fill="#e79d4f" stroke="#ffd17c"/><circle cx="64" cy="65" r="22" fill="#a94c57"/><path d="M64 50V68M64 79V80"/>',
		"fuse": '<circle cx="61" cy="77" r="29" fill="#696575"/><path d="M61 48Q51 28 75 27Q96 28 96 15M87 17L109 30M87 30L109 12" stroke="#f1bd6c"/><path d="M49 66L72 89M72 66L49 89" stroke="#e5a8b1"/>',
		"weakness": '<path d="M64 104L28 69Q12 43 32 30Q51 18 64 41Q77 18 96 30Q116 43 100 69Z" fill="#bd6a83"/><path d="M66 37L55 59L73 68L59 91" stroke="#492b3c" stroke-width="8"/>',
		"overcrowding": '<circle cx="40" cy="41" r="18" fill="#ba6c7f"/><circle cx="88" cy="41" r="18" fill="#ba6c7f"/><circle cx="64" cy="87" r="18" fill="#ba6c7f"/><path d="M40 16V23M16 41H22M88 16V23M106 41H113M64 62V69M40 87H46M82 87H88M64 105V113"/><path d="M34 35H40M82 35H88M58 81H64" stroke="#ffcfda" stroke-width="3"/>',
		"dig_tax": '<path d="M24 104L70 55M35 40Q65 28 92 52L82 64Q62 47 35 52" stroke="#d6c6ac"/><circle cx="90" cy="31" r="19" fill="#efc15e" stroke="#ffdfa0"/><path d="M81 31H99M90 22V40" stroke="#98552e"/>',
		"reward_cut": '<circle cx="50" cy="55" r="30" fill="#e1af5b" stroke="#ffe09b"/><path d="M50 37V73M39 46H59M41 63H61" stroke="#906228"/><path d="M90 66V107M77 93L90 107L104 93" stroke="#ff9aa9" stroke-width="8"/>',
		"interference": '<path d="M64 66V108M45 108H83M39 54Q29 43 39 30M89 30Q99 43 89 54M24 68Q4 43 24 16M104 16Q124 43 104 68" stroke="#d4b7d2"/><circle cx="64" cy="43" r="9" fill="#d4b7d2"/><path d="M21 106L106 21" stroke="#f18b9f" stroke-width="8"/>',
		"instrument": '<path d="M21 99V70A43 43 0 0 1 107 70V99Z" fill="#686a82"/><path d="M64 76L87 48M34 68L41 70M48 40L52 47M82 39L78 46" stroke="#e1d8ed"/><circle cx="64" cy="76" r="6" fill="#f7b274"/><path d="M49 103L58 92L68 104L79 92L89 103" stroke="#e6a8b8"/>',
		"unstable_ground": '<path d="M16 51H112V102H16Z" fill="#90726a"/><path d="M66 27L56 51L71 64L53 80L68 103" stroke="#442b38" stroke-width="9"/><path d="M25 72H40M86 78H103M33 32L39 43M99 29L91 42" stroke="#f0c395"/>',
	}
	return drawings.get(id, "")
