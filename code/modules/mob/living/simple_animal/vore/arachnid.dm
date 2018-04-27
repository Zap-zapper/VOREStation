/mob/living/simple_animal/hostile/mega_arachnid
	name = "mega arachnid"
	desc = "Though physically imposing, it prefers to ambush its prey, and it will only engage with an already crippled opponent."
	icon = 'icons/mob/vore64x64.dmi'

	icon_living = "arachnid"
	icon_state = "arachnid"

	icon_dead = "arachnid_dead"
	icon_resting = "arachnid_sleeping"
	var/icon_stunned = "arachnid_stunned"

	faction = "arachnid"
	maxHealth = 500
	health = 500

	melee_damage_lower = 10
	melee_damage_upper = 60

	min_oxy = 0
	max_oxy = 0
	min_tox = 0
	max_tox = 0
	min_co2 = 0
	max_co2 = 0
	min_n2 = 0
	max_n2 = 0
	minbodytemp = 0

	old_x = -16
	old_y = 0
	default_pixel_x = -16
	pixel_x = -16
	pixel_y = 0

	//Try to legcuff prey
	spattack_prob = 10
	spattack_min_range = 3
	spattack_max_range = 10

	armor = list(
		"melee" = 60,
		"bullet" = 50,
		"laser" = 50,
		"energy" = 50,
		"bomb" = 40,
		"bio" = 100,
		"rad" = 100)

/mob/living/simple_animal/hostile/mega_arachnid/FindTarget()
	. = ..()
	if(.)
		custom_emote(1,"snaps at [.]")

/mob/living/simple_animal/hostile/mega_arachnid/Life()
	if((. = ..()))
		if(stance == STANCE_ATTACK || stance == STANCE_ATTACKING)
			alpha = 255
		else
			alpha = 60

// Activate Noms!
/mob/living/simple_animal/hostile/mega_arachnid
	vore_active = 1
	vore_capacity = 2
	vore_pounce_chance = 0 // Beat them into crit before eating.
	vore_icons = 0
