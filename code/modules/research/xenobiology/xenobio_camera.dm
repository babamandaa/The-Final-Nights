//Xenobio control console
/mob/camera/ai_eye/remote/xenobio
	visible_icon = TRUE
	icon = 'icons/mob/cameramob.dmi'
	icon_state = "generic_camera"
	var/allowed_area = null

/mob/camera/ai_eye/remote/xenobio/Initialize()
	var/area/A = get_area(loc)
	allowed_area = A.name
	. = ..()

/mob/camera/ai_eye/remote/xenobio/setLoc(t)
	var/area/new_area = get_area(t)
	if(new_area && new_area.name == allowed_area || new_area && (new_area.area_flags & XENOBIOLOGY_COMPATIBLE))
		return ..()
	else
		return

/obj/machinery/computer/camera_advanced/xenobio
	name = "Slime management console"
	desc = "A computer used for remotely handling slimes."
	networks = list("ss13")
	circuit = /obj/item/circuitboard/computer/xenobiology
	var/datum/action/innate/slime_place/slime_place_action
	var/datum/action/innate/slime_pick_up/slime_up_action
	var/datum/action/innate/feed_slime/feed_slime_action
	var/datum/action/innate/monkey_recycle/monkey_recycle_action
	var/datum/action/innate/slime_scan/scan_action
	var/datum/action/innate/feed_potion/potion_action
	var/datum/action/innate/hotkey_help/hotkey_help

	var/obj/machinery/monkey_recycler/connected_recycler
	var/list/stored_slimes
	var/obj/item/slimepotion/slime/current_potion
	var/max_slimes = 5
	var/monkeys = 0

	icon_screen = "slime_comp"
	icon_keyboard = "rd_key"

	light_color = LIGHT_COLOR_PINK

/obj/machinery/computer/camera_advanced/xenobio/Initialize(mapload)
	. = ..()
	slime_place_action = new
	slime_up_action = new
	feed_slime_action = new
	monkey_recycle_action = new
	scan_action = new
	potion_action = new
	hotkey_help = new
	stored_slimes = list()
	for(var/obj/machinery/monkey_recycler/recycler in GLOB.monkey_recyclers)
		if(get_area(recycler.loc) == get_area(loc))
			connected_recycler = recycler
			connected_recycler.connected += src

/obj/machinery/computer/camera_advanced/xenobio/Destroy()
	QDEL_NULL(current_potion)
	for(var/thing in stored_slimes)
		var/mob/living/simple_animal/slime/S = thing
		S.forceMove(drop_location())
	stored_slimes.Cut()
	if(connected_recycler)
		connected_recycler.connected -= src
	connected_recycler = null
	return ..()

/obj/machinery/computer/camera_advanced/xenobio/handle_atom_del(atom/A)
	if(A == current_potion)
		current_potion = null
	if(A in stored_slimes)
		stored_slimes -= A
	return ..()

/obj/machinery/computer/camera_advanced/xenobio/CreateEye()
	eyeobj = new /mob/camera/ai_eye/remote/xenobio(get_turf(src))
	eyeobj.origin = src
	eyeobj.visible_icon = TRUE
	eyeobj.icon = 'icons/mob/cameramob.dmi'
	eyeobj.icon_state = "generic_camera"

/obj/machinery/computer/camera_advanced/xenobio/GrantActions(mob/living/user)
	..()

	if(slime_up_action)
		slime_up_action.target = src
		slime_up_action.Grant(user)
		actions += slime_up_action

	if(slime_place_action)
		slime_place_action.target = src
		slime_place_action.Grant(user)
		actions += slime_place_action

	if(feed_slime_action)
		feed_slime_action.target = src
		feed_slime_action.Grant(user)
		actions += feed_slime_action

	if(monkey_recycle_action)
		monkey_recycle_action.target = src
		monkey_recycle_action.Grant(user)
		actions += monkey_recycle_action

	if(scan_action)
		scan_action.target = src
		scan_action.Grant(user)
		actions += scan_action

	if(potion_action)
		potion_action.target = src
		potion_action.Grant(user)
		actions += potion_action

	if(hotkey_help)
		hotkey_help.target = src
		hotkey_help.Grant(user)
		actions += hotkey_help

	RegisterSignal(user, COMSIG_MOB_CTRL_CLICKED, PROC_REF(on_ctrl_click))
	RegisterSignal(user, COMSIG_XENO_SLIME_CLICK_ALT, PROC_REF(XenoSlimeClickAlt))
	RegisterSignal(user, COMSIG_XENO_SLIME_CLICK_SHIFT, PROC_REF(XenoSlimeClickShift))
	RegisterSignal(user, COMSIG_XENO_TURF_CLICK_SHIFT, PROC_REF(XenoTurfClickShift))

	//Checks for recycler on every interact, prevents issues with load order on certain maps.
	if(!connected_recycler)
		for(var/obj/machinery/monkey_recycler/recycler in GLOB.monkey_recyclers)
			if(get_area(recycler.loc) == get_area(loc))
				connected_recycler = recycler
				connected_recycler.connected += src

/obj/machinery/computer/camera_advanced/xenobio/remove_eye_control(mob/living/user)
	UnregisterSignal(user, COMSIG_MOB_CTRL_CLICKED)
	UnregisterSignal(user, COMSIG_XENO_SLIME_CLICK_ALT)
	UnregisterSignal(user, COMSIG_XENO_SLIME_CLICK_SHIFT)
	UnregisterSignal(user, COMSIG_XENO_TURF_CLICK_SHIFT)
	..()

/obj/machinery/computer/camera_advanced/xenobio/attackby(obj/item/O, mob/user, params)
	if(istype(O, /obj/item/food/monkeycube))
		monkeys++
		to_chat(user, "<span class='notice'>You feed [O] to [src]. It now has [monkeys] monkey cubes stored.</span>")
		qdel(O)
		return
	else if(istype(O, /obj/item/storage/bag))
		var/obj/item/storage/P = O
		var/loaded = FALSE
		for(var/obj/G in P.contents)
			if(istype(G, /obj/item/food/monkeycube))
				loaded = TRUE
				monkeys++
				qdel(G)
		if(loaded)
			to_chat(user, "<span class='notice'>You fill [src] with the monkey cubes stored in [O]. [src] now has [monkeys] monkey cubes stored.</span>")
		return
	else if(istype(O, /obj/item/slimepotion/slime))
		var/replaced = FALSE
		if(user && !user.transferItemToLoc(O, src))
			return
		if(!QDELETED(current_potion))
			current_potion.forceMove(drop_location())
			replaced = TRUE
		current_potion = O
		to_chat(user, "<span class='notice'>You load [O] in the console's potion slot[replaced ? ", replacing the one that was there before" : ""].</span>")
		return
	else if(istype(O, /obj/item/slime_extract))
		var/obj/item/slime_extract/E = O
		if(!SSresearch.slime_already_researched[E.type])
			if(!E.research)
				playsound(src, 'sound/machines/buzz-sigh.ogg', 50, 3, -1)
				visible_message("<span class='notice'>[src] buzzes and displays a message: Invalid extract! (You shouldn't be seeing this. If you are, tell someone.)</span>")
				return
			if(E.Uses <= 0)
				playsound(src, 'sound/machines/buzz-sigh.ogg', 50, 3, -1)
				visible_message("<span class='notice'>[src] buzzes and displays a message: Extract consumed - no research available.</span>")
				return
			else
				playsound(src, 'sound/machines/ping.ogg', 50, 3, -1)
				visible_message("<span class='notice'>You insert [E] into a slot on the [src]. It pings and prints out some research notes worth [E.research] points!</span>")
				new /obj/item/research_notes(drop_location(), E.research, "xenobiology")
				SSresearch.slime_already_researched[E.type] = TRUE
				qdel(O)
				return
		else
			visible_message("<span class='notice'>[src] buzzes and displays a message: Slime extract already researched!</span>")
			playsound(src, 'sound/machines/buzz-sigh.ogg', 50, 3, -1)
			return
	..()

/obj/machinery/computer/camera_advanced/xenobio/multitool_act(mob/living/user, obj/item/multitool/I)
	. = ..()
	if (istype(I) && istype(I.buffer,/obj/machinery/monkey_recycler))
		to_chat(user, "<span class='notice'>You link [src] with [I.buffer] in [I] buffer.</span>")
		connected_recycler = I.buffer
		connected_recycler.connected += src
		return TRUE

/datum/action/innate/slime_place
	name = "Place Slimes"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "slime_down"

/datum/action/innate/slime_place/Activate()
	if(!target || !isliving(owner))
		return
	var/mob/living/C = owner
	var/mob/camera/ai_eye/remote/xenobio/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = target

	if(GLOB.cameranet.checkTurfVis(remote_eye.loc))
		for(var/mob/living/simple_animal/slime/S in X.stored_slimes)
			S.forceMove(remote_eye.loc)
			S.visible_message("<span class='notice'>[S] warps in!</span>")
			X.stored_slimes -= S
	else
		to_chat(owner, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")

/datum/action/innate/slime_pick_up
	name = "Pick up Slime"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "slime_up"

/datum/action/innate/slime_pick_up/Activate()
	if(!target || !isliving(owner))
		return
	var/mob/living/C = owner
	var/mob/camera/ai_eye/remote/xenobio/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = target

	if(GLOB.cameranet.checkTurfVis(remote_eye.loc))
		for(var/mob/living/simple_animal/slime/S in remote_eye.loc)
			if(X.stored_slimes.len >= X.max_slimes)
				break
			if(!S.ckey)
				if(S.buckled)
					S.Feedstop(silent = TRUE)
				S.visible_message("<span class='notice'>[S] vanishes in a flash of light!</span>")
				S.forceMove(X)
				X.stored_slimes += S
	else
		to_chat(owner, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")


/datum/action/innate/feed_slime
	name = "Feed Slimes"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "monkey_down"

/datum/action/innate/feed_slime/Activate()
	if(!target || !isliving(owner))
		return
	var/mob/living/C = owner
	var/mob/camera/ai_eye/remote/xenobio/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = target

	if(GLOB.cameranet.checkTurfVis(remote_eye.loc))
		if(X.monkeys >= 1)
			var/mob/living/carbon/human/species/monkey/food = new /mob/living/carbon/human/species/monkey(remote_eye.loc, TRUE, owner)
			if (!QDELETED(food))
				food.LAssailant = C
				X.monkeys--
				X.monkeys = round(X.monkeys, 0.1)		//Prevents rounding errors
				to_chat(owner, "<span class='notice'>[X] now has [X.monkeys] monkeys stored.</span>")
		else
			to_chat(owner, "<span class='warning'>[X] needs to have at least 1 monkey stored. Currently has [X.monkeys] monkeys stored.</span>")
	else
		to_chat(owner, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")


/datum/action/innate/monkey_recycle
	name = "Recycle Monkeys"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "monkey_up"

/datum/action/innate/monkey_recycle/Activate()
	if(!target || !isliving(owner))
		return
	var/mob/living/C = owner
	var/mob/camera/ai_eye/remote/xenobio/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = target
	var/obj/machinery/monkey_recycler/recycler = X.connected_recycler

	if(!recycler)
		to_chat(owner, "<span class='warning'>There is no connected monkey recycler. Use a multitool to link one.</span>")
		return
	if(GLOB.cameranet.checkTurfVis(remote_eye.loc))
		for(var/mob/living/carbon/human/M in remote_eye.loc)
			if(!ismonkey(M))
				continue
			if(M.stat)
				M.visible_message("<span class='notice'>[M] vanishes as [M.p_theyre()] reclaimed for recycling!</span>")
				recycler.use_power(500)
				X.monkeys += recycler.cube_production
				X.monkeys = round(X.monkeys, 0.1)		//Prevents rounding errors
				qdel(M)
				to_chat(owner, "<span class='notice'>[X] now has [X.monkeys] monkeys available.</span>")
	else
		to_chat(owner, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")

/datum/action/innate/slime_scan
	name = "Scan Slime"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "slime_scan"

/datum/action/innate/slime_scan/Activate()
	if(!target || !isliving(owner))
		return
	var/mob/living/C = owner
	var/mob/camera/ai_eye/remote/xenobio/remote_eye = C.remote_control

	if(GLOB.cameranet.checkTurfVis(remote_eye.loc))
		for(var/mob/living/simple_animal/slime/S in remote_eye.loc)
			slime_scan(S, C)
	else
		to_chat(owner, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")

/datum/action/innate/feed_potion
	name = "Apply Potion"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "slime_potion"

/datum/action/innate/feed_potion/Activate()
	if(!target || !isliving(owner))
		return

	var/mob/living/C = owner
	var/mob/camera/ai_eye/remote/xenobio/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = target

	if(QDELETED(X.current_potion))
		to_chat(owner, "<span class='warning'>No potion loaded.</span>")
		return

	if(GLOB.cameranet.checkTurfVis(remote_eye.loc))
		for(var/mob/living/simple_animal/slime/S in remote_eye.loc)
			X.current_potion.attack(S, C)
			break
	else
		to_chat(owner, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")

/datum/action/innate/hotkey_help
	name = "Hotkey Help"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "hotkey_help"

/datum/action/innate/hotkey_help/Activate()
	if(!target || !isliving(owner))
		return

	var/render_list = list()
	render_list += "<b>Click shortcuts:</b>"
	render_list += "&bull; Shift-click a slime to pick it up, or the floor to drop all held slimes."
	render_list += "&bull; Ctrl-click a slime to scan it."
	render_list += "&bull; Alt-click a slime to feed it a potion."
	render_list += "&bull; Ctrl-click or a dead monkey to recycle it, or the floor to place a new monkey."

	to_chat(owner, boxed_message(jointext(render_list, "\n")))

//
// Alternate clicks for slime, monkey and open turf if using a xenobio console


//Feeds a potion to slime
/mob/living/simple_animal/slime/AltClick(mob/user)
	SEND_SIGNAL(user, COMSIG_XENO_SLIME_CLICK_ALT, src)
	..()

//Picks up slime
/mob/living/simple_animal/slime/ShiftClick(mob/user)
	SEND_SIGNAL(user, COMSIG_XENO_SLIME_CLICK_SHIFT, src)
	..()

//Place slimes
/turf/open/ShiftClick(mob/user)
	SEND_SIGNAL(user, COMSIG_XENO_TURF_CLICK_SHIFT, src)
	..()

/obj/machinery/computer/camera_advanced/xenobio/proc/on_ctrl_click(datum/source, atom/clicked_atom)
	SIGNAL_HANDLER
	if(ismonkey(clicked_atom))
		XenoMonkeyClickCtrl(source, clicked_atom)
	if(isopenturf(clicked_atom))
		XenoTurfClickCtrl(source, clicked_atom)
	if(isslime(clicked_atom))
		XenoSlimeClickCtrl(source, clicked_atom)

// Scans slime
/obj/machinery/computer/camera_advanced/xenobio/proc/XenoSlimeClickCtrl(mob/living/user, mob/living/simple_animal/slime/S)
	if(!GLOB.cameranet.checkTurfVis(S.loc))
		to_chat(user, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")
		return
	var/mob/living/C = user
	var/mob/camera/ai_eye/remote/xenobio/E = C.remote_control
	var/area/mobarea = get_area(S.loc)
	if(mobarea.name == E.allowed_area || (mobarea.area_flags & XENOBIOLOGY_COMPATIBLE))
		slime_scan(S, C)

//Feeds a potion to slime
/obj/machinery/computer/camera_advanced/xenobio/proc/XenoSlimeClickAlt(mob/living/user, mob/living/simple_animal/slime/S)
	if(!GLOB.cameranet.checkTurfVis(S.loc))
		to_chat(user, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")
		return
	var/mob/living/C = user
	var/mob/camera/ai_eye/remote/xenobio/E = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = E.origin
	var/area/mobarea = get_area(S.loc)
	if(QDELETED(X.current_potion))
		to_chat(C, "<span class='warning'>No potion loaded.</span>")
		return
	if(mobarea.name == E.allowed_area || (mobarea.area_flags & XENOBIOLOGY_COMPATIBLE))
		X.current_potion.attack(S, C)

//Picks up slime
/obj/machinery/computer/camera_advanced/xenobio/proc/XenoSlimeClickShift(mob/living/user, mob/living/simple_animal/slime/S)
	if(!GLOB.cameranet.checkTurfVis(S.loc))
		to_chat(user, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")
		return
	var/mob/living/C = user
	var/mob/camera/ai_eye/remote/xenobio/E = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = E.origin
	var/area/mobarea = get_area(S.loc)
	if(mobarea.name == E.allowed_area || (mobarea.area_flags & XENOBIOLOGY_COMPATIBLE))
		if(X.stored_slimes.len >= X.max_slimes)
			to_chat(C, "<span class='warning'>Slime storage is full.</span>")
			return
		if(S.ckey)
			to_chat(C, "<span class='warning'>The slime wiggled free!</span>")
			return
		if(S.buckled)
			S.Feedstop(silent = TRUE)
		S.visible_message("<span class='notice'>[S] vanishes in a flash of light!</span>")
		S.forceMove(X)
		X.stored_slimes += S

//Place slimes
/obj/machinery/computer/camera_advanced/xenobio/proc/XenoTurfClickShift(mob/living/user, turf/open/T)
	if(!GLOB.cameranet.checkTurfVis(T))
		to_chat(user, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")
		return
	var/mob/living/C = user
	var/mob/camera/ai_eye/remote/xenobio/E = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = E.origin
	var/area/turfarea = get_area(T)
	if(turfarea.name == E.allowed_area || (turfarea.area_flags & XENOBIOLOGY_COMPATIBLE))
		for(var/mob/living/simple_animal/slime/S in X.stored_slimes)
			S.forceMove(T)
			S.visible_message("<span class='notice'>[S] warps in!</span>")
			X.stored_slimes -= S

//Place monkey
/obj/machinery/computer/camera_advanced/xenobio/proc/XenoTurfClickCtrl(mob/living/user, turf/open/T)
	if(!GLOB.cameranet.checkTurfVis(T))
		to_chat(user, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")
		return
	var/mob/living/C = user
	var/mob/camera/ai_eye/remote/xenobio/E = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = E.origin
	var/area/turfarea = get_area(T)
	if(turfarea.name == E.allowed_area || (turfarea.area_flags & XENOBIOLOGY_COMPATIBLE))
		if(X.monkeys >= 1)
			var/mob/living/carbon/human/food = new /mob/living/carbon/human/species/monkey(T, TRUE, C)
			if (!QDELETED(food))
				food.LAssailant = C
				X.monkeys--
				X.monkeys = round(X.monkeys, 0.1)		//Prevents rounding errors
				to_chat(C, "<span class='notice'>[X] now has [X.monkeys] monkeys stored.</span>")
		else
			to_chat(C, "<span class='warning'>[X] needs to have at least 1 monkey stored. Currently has [X.monkeys] monkeys stored.</span>")

//Pick up monkey
/obj/machinery/computer/camera_advanced/xenobio/proc/XenoMonkeyClickCtrl(mob/living/user, mob/living/carbon/human/M)
	if(!ismonkey(M))
		return
	if(!isturf(M.loc) || !GLOB.cameranet.checkTurfVis(M.loc))
		to_chat(user, "<span class='warning'>Target is not near a camera. Cannot proceed.</span>")
		return
	var/mob/living/C = user
	var/mob/camera/ai_eye/remote/xenobio/E = C.remote_control
	var/obj/machinery/computer/camera_advanced/xenobio/X = E.origin
	var/area/mobarea = get_area(M.loc)
	if(!X.connected_recycler)
		to_chat(C, "<span class='warning'>There is no connected monkey recycler. Use a multitool to link one.</span>")
		return
	if(mobarea.name == E.allowed_area || (mobarea.area_flags & XENOBIOLOGY_COMPATIBLE))
		if(!M.stat)
			return
		M.visible_message("<span class='notice'>[M] vanishes as [p_theyre()] reclaimed for recycling!</span>")
		X.connected_recycler.use_power(500)
		X.monkeys += connected_recycler.cube_production
		X.monkeys = round(X.monkeys, 0.1)		//Prevents rounding errors
		qdel(M)
		to_chat(C, "<span class='notice'>[X] now has [X.monkeys] monkeys available.</span>")
