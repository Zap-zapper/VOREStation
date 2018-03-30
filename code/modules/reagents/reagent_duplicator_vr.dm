/obj/machinery/power/chem_duplicator
	name = "ThunderBuns 3000"
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "mixer0"
	use_power = 1
	idle_power_usage = 20
	flags = OPENCONTAINER
	circuit = /obj/item/weapon/circuitboard/chem_duplicator

	var/on = FALSE
	var/selected_reagent_id = null
	var/obj/item/weapon/reagent_containers/beaker = null
	var/reagents_max_volume = 120
	var/power_per_unit = 1e5
	var/heat_per_unit = 500 // TODO wot
	var/units_per_tick = 0.1
	var/catalyst_per_unit = 0.05
	var/catalyst_reagent = "platinum"

/obj/machinery/power/chem_duplicator/initialize()
	. = ..()
	create_reagents(reagents_max_volume)
	default_apply_parts()
	if(anchored)
		connect_to_network()

/obj/machinery/power/chem_duplicator/RefreshParts()
	var/cap_rating = 0
	var/bin_rating = 0
	var/manip_rating = 0
	for(var/obj/item/weapon/stock_parts/P in component_parts)
		if(istype(P, /obj/item/weapon/stock_parts/capacitor))
			cap_rating += P.rating
		if(istype(P, /obj/item/weapon/stock_parts/matter_bin))
			bin_rating += P.rating
		if(istype(P, /obj/item/weapon/stock_parts/manipulator))
			manip_rating += P.rating
	power_per_unit = round(initial(power_per_unit) / cap_rating)
	units_per_tick = initial(units_per_tick) + (manip_rating**2 - 1) // 1x, 3x, 8x
	heat_per_unit = round(initial(heat_per_unit) / ((cap_rating + manip_rating)*0.5))
	reagents.maximum_volume = initial(reagents_max_volume) * bin_rating

/obj/machinery/power/chem_duplicator/dismantle()
	// Spill all of our contained reagents onto the turf.  They should have emptied us first
	reagents.trans_to(drop_location(), reagents.total_volume)
	. = ..()


/obj/machinery/power/chem_duplicator/process()
	if(!on)
		return
	if(!powernet)
		turn_off()
		return
	if(!selected_reagent_id)
		turn_off()
		return

	// Draw power needed for duplication
	var/needed_power = units_per_tick * power_per_unit
	if(draw_power(needed_power) < needed_power)
		var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
		s.set_up(5, 1, src)
		s.start()
		return

	// Generate heat!
	var/datum/gas_mixture/env = return_air()
	if(env)
		var/transfer_moles = 0.25 * env.total_moles
		var/datum/gas_mixture/removed = env.remove(transfer_moles)
		if(removed)
			var/heat_produced = units_per_tick * heat_per_unit
			removed.add_thermal_energy(heat_produced)
			env.merge(removed)

	// TODO - consume the catalyst
	var/catalyst_needed = round(units_per_tick * catalyst_per_unit, 0.01)
	if(!reagents.has_reagent(catalyst_reagent, catalyst_needed))
		// Uh oh! Drew power but ran out of catalyst!  Bad things happen now.
		visible_message("<span class='danger'>Warning: Overload! Catalyst exhausted!</span>")
		empulse(get_turf(src), 2, 4, 8, 16, TRUE)
		turn_off()
	reagents.remove_reagent(catalyst_reagent, catalyst_needed)

	// Add the selected reagent!
	reagents.add_reagent(selected_reagent_id, units_per_tick)
	playsound(src, 'sound/effects/bubbles.ogg', 20) // Quiet bubbling

/obj/machinery/power/chem_duplicator/proc/turn_off()
	if(on)
		playsound(src, 'sound/effects/basscannon.ogg', 50)
	on = FALSE
	update_icon()

/obj/machinery/power/chem_duplicator/attackby(var/obj/item/weapon/W as obj, var/mob/user as mob)
	src.add_fingerprint(user)

	if(istype(W, /obj/item/weapon/reagent_containers/glass))
		if(beaker)
			to_chat(user, "\A [beaker] is already loaded into the machine.")
		else if(user.unEquip(W))
			W.forceMove(src)
			beaker = W
			to_chat(user, "You add \the [W] to the machine!")
			icon_state = "mixer1"
		return
	else if(default_deconstruction_screwdriver(user, W))
		return
	else if(default_part_replacement(user, W))
		return
	else if(default_unfasten_wrench(user, W, 20))
		return
	else if(default_deconstruction_crowbar(user, W))
		return
	return ..()

/obj/machinery/power/chem_duplicator/attack_hand(mob/user as mob)
	if(..())
		return 1
	user.set_machine(src)
	ui_interact(user)

/**
 *  Display the NanoUI window for the chem master.
 *
 *  See NanoUI documentation for details.
 */
/obj/machinery/power/chem_duplicator/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)
	user.set_machine(src)

	var/list/data = list()
	data["tab"] = tab
	data["condi"] = condi

	if(loaded_pill_bottle)
		data["pillBottle"] = list("total" = loaded_pill_bottle.contents.len, "max" = loaded_pill_bottle.max_storage_space)
	else
		data["pillBottle"] = null

	if(beaker)
		var/datum/reagents/R = beaker:reagents
		var/ui_reagent_beaker_list[0]
		for(var/datum/reagent/G in R.reagent_list)
			ui_reagent_beaker_list[++ui_reagent_beaker_list.len] = list("name" = G.name, "volume" = G.volume, "description" = G.description, "id" = G.id)

		data["beaker"] = list("total_volume" = R.total_volume, "reagent_list" = ui_reagent_beaker_list)
	else
		data["beaker"] = null

	if(reagents.total_volume)
		var/ui_reagent_list[0]
		for(var/datum/reagent/N in reagents.reagent_list)
			ui_reagent_list[++ui_reagent_list.len] = list("name" = N.name, "volume" = N.volume, "description" = N.description, "id" = N.id)

		data["reagents"] = list("total_volume" = reagents.total_volume, "reagent_list" = ui_reagent_list)
	else
		data["reagents"] = null

	data["mode"] = mode

	if(analyze_data)
		data["analyzeData"] = list("name" = analyze_data["name"], "desc" = analyze_data["desc"], "blood_type" = analyze_data["blood_type"], "blood_DNA" = analyze_data["blood_DNA"])
	else
		data["analyzeData"] = null

	data["pillSprite"] = pillsprite
	data["bottleSprite"] = bottlesprite

	var/P[20] //how many pill sprites there are. Sprites are taken from chemical.dmi and can be found in nano/images/pill.png
	for(var/i = 1 to P.len)
		P[i] = i
	data["pillSpritesAmount"] = P

	data["bottleSpritesAmount"] = list(1, 2, 3, 4) //how many bottle sprites there are. Sprites are taken from chemical.dmi and can be found in nano/images/pill.png

	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "chem_master.tmpl", src.name, 575, 400)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(5)

/obj/machinery/power/chem_duplicator/Topic(href, href_list)
	if(stat & (BROKEN|NOPOWER)) return
	if(usr.stat || usr.restrained()) return
	if(!in_range(src, usr)) return

	src.add_fingerprint(usr)
	usr.set_machine(src)

	if(href_list["tab_select"])
		tab = href_list["tab_select"]

	if (href_list["ejectp"])
		if(loaded_pill_bottle)
			loaded_pill_bottle.loc = src.loc
			loaded_pill_bottle = null

	if(beaker)
		var/datum/reagents/R = beaker:reagents
		if (tab == "analyze")
			analyze_data["name"] = href_list["name"]
			analyze_data["desc"] = href_list["desc"]
			if(!condi)
				if(href_list["name"] == "Blood")
					var/datum/reagent/blood/G
					for(var/datum/reagent/F in R.reagent_list)
						if(F.name == href_list["name"])
							G = F
							break
					analyze_data["name"] = G.name
					analyze_data["blood_type"] = G.data["blood_type"]
					analyze_data["blood_DNA"] = G.data["blood_DNA"]

		else if (href_list["add"])

			if(href_list["amount"])
				var/id = href_list["add"]
				var/amount = Clamp((text2num(href_list["amount"])), 0, 200)
				R.trans_id_to(src, id, amount)

		else if (href_list["addcustom"])

			var/id = href_list["addcustom"]
			useramount = input("Select the amount to transfer.", 30, useramount) as num
			useramount = Clamp(useramount, 0, 200)
			src.Topic(null, list("amount" = "[useramount]", "add" = "[id]"))

		else if (href_list["remove"])

			if(href_list["amount"])
				var/id = href_list["remove"]
				var/amount = Clamp((text2num(href_list["amount"])), 0, 200)
				if(mode)
					reagents.trans_id_to(beaker, id, amount)
				else
					reagents.remove_reagent(id, amount)


		else if (href_list["removecustom"])

			var/id = href_list["removecustom"]
			useramount = input("Select the amount to transfer.", 30, useramount) as num
			useramount = Clamp(useramount, 0, 200)
			src.Topic(null, list("amount" = "[useramount]", "remove" = "[id]"))

		else if (href_list["toggle"])
			mode = !mode

		else if (href_list["eject"])
			if(beaker)
				beaker:loc = src.loc
				beaker = null
				reagents.clear_reagents()
				icon_state = "mixer0"
		else if (href_list["createpill"] || href_list["createpill_multiple"])
			var/count = 1

			if(reagents.total_volume/count < 1) //Sanity checking.
				return

			if (href_list["createpill_multiple"])
				count = input("Select the number of pills to make.", "Max [max_pill_count]", pillamount) as num
				count = Clamp(count, 1, max_pill_count)

			if(reagents.total_volume/count < 1) //Sanity checking.
				return

			var/amount_per_pill = reagents.total_volume/count
			if (amount_per_pill > 60) amount_per_pill = 60

			var/name = sanitizeSafe(input(usr,"Name:","Name your pill!","[reagents.get_master_reagent_name()] ([amount_per_pill] units)"), MAX_NAME_LEN)

			if(reagents.total_volume/count < 1) //Sanity checking.
				return
			while (count--)
				var/obj/item/weapon/reagent_containers/pill/P = new/obj/item/weapon/reagent_containers/pill(src.loc)
				if(!name) name = reagents.get_master_reagent_name()
				P.name = "[name] pill"
				P.pixel_x = rand(-7, 7) //random position
				P.pixel_y = rand(-7, 7)
				P.icon_state = "pill"+pillsprite
				reagents.trans_to_obj(P,amount_per_pill)
				if(src.loaded_pill_bottle)
					if(loaded_pill_bottle.contents.len < loaded_pill_bottle.max_storage_space)
						P.loc = loaded_pill_bottle

		else if (href_list["createbottle"])
			if(!condi)
				var/name = sanitizeSafe(input(usr,"Name:","Name your bottle!",reagents.get_master_reagent_name()), MAX_NAME_LEN)
				var/obj/item/weapon/reagent_containers/glass/bottle/P = new/obj/item/weapon/reagent_containers/glass/bottle(src.loc)
				if(!name) name = reagents.get_master_reagent_name()
				P.name = "[name] bottle"
				P.pixel_x = rand(-7, 7) //random position
				P.pixel_y = rand(-7, 7)
				P.icon_state = "bottle-"+bottlesprite
				reagents.trans_to_obj(P,60)
				P.update_icon()
			else
				var/obj/item/weapon/reagent_containers/food/condiment/P = new/obj/item/weapon/reagent_containers/food/condiment(src.loc)
				reagents.trans_to_obj(P,50)

		else if(href_list["pill_sprite"])
			pillsprite = href_list["pill_sprite"]
		else if(href_list["bottle_sprite"])
			bottlesprite = href_list["bottle_sprite"]

	nanomanager.update_uis(src)
