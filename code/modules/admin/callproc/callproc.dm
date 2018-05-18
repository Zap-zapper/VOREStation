var/AdminProcCaller
var/AdminProcCallCount = 0
var/LastAdminCalledTargetRef
var/LastAdminCalledTarget
var/LastAdminCalledProc
var/AdminProcCallSpamPrevention = list()

/proc/WrapAdminProcCall(target, procname, list/arguments)
	if(target && procname == "Del")
		to_chat(usr, "Calling Del() is not allowed")
		return
	var/current_caller = global.AdminProcCaller
	var/ckey = usr ? usr.client.ckey : global.AdminProcCaller
	if(!ckey)
		CRASH("WrapAdminProcCall with no ckey: [target] [procname] [english_list(arguments)]")
	if(current_caller && current_caller != ckey)
		if(!global.AdminProcCallSpamPrevention[ckey])
			to_chat(usr, "<span class='adminnotice'>Another set of admin called procs are still running, your proc will be run after theirs finish.</span>")
			global.AdminProcCallSpamPrevention[ckey] = TRUE
			UNTIL(!global.AdminProcCaller)
			to_chat(usr, "<span class='adminnotice'>Running your proc</span>")
			global.AdminProcCallSpamPrevention -= ckey
		else
			UNTIL(!global.AdminProcCaller)
	global.LastAdminCalledProc = procname
	if(target != GLOBAL_PROC)
		global.LastAdminCalledTargetRef = "\ref[target]"
	global.AdminProcCaller = ckey	//if this runtimes, too bad for you
	++global.AdminProcCallCount
	. = world.WrapAdminProcCall(target, procname, arguments)
	if(--global.AdminProcCallCount == 0)
		global.AdminProcCaller = null

//adv proc call this, ya nerds
/world/proc/WrapAdminProcCall(target, procname, list/arguments)
	if(target == GLOBAL_PROC)
		return call(procname)(arglist(arguments))
	else if(target != world)
		return call(target, procname)(arglist(arguments))
	else
		log_and_message_admins("[key_name(usr)] attempted to call world/proc/[procname] with arguments: [english_list(arguments)]")

/client/proc/callproc()
	set category = "Debug"
	set name = "Advanced ProcCall"

	if(!check_rights(R_DEBUG)) return
	if(config.debugparanoid && !check_rights(R_ADMIN)) return

	var/target = null
	var/targetselected = 0

	switch(alert("Proc owned by something?",, "Yes", "No", "Cancel"))
		if("Yes")
			targetselected=1
			switch(input("Proc owned by...", "Owner", null) as null|anything in list("Obj", "Mob", "Area or Turf", "Client"))
				if("Obj")
					target = input("Select target:", "Target") as null|obj in world
				if("Mob")
					target = input("Select target:", "Target", usr) as null|mob in world
				if("Area or Turf")
					target = input("Select target:", "Target", get_turf(usr)) as null|area|turf in world
				if("Client")
					target = input("Select target:", "Target", usr.client) as null|anything in clients
				else
					return
			if(!target)
				usr << "Proc call cancelled."
				return
		if("Cancel")
			return
		if("No")
			; // do nothing

	callproc_targetpicked(targetselected, target)

/client/proc/callproc_target(atom/A in world)
	set category = "Debug"
	set name = "Advanced ProcCall Target"

	if(!check_rights(R_DEBUG)) return
	if(config.debugparanoid && !check_rights(R_ADMIN)) return

	callproc_targetpicked(1, A)

/client/proc/callproc_targetpicked(hastarget, datum/target)

	// this needs checking again here because VV's 'Call Proc' option directly calls this proc with the target datum
	if(!check_rights(R_DEBUG)) return
	if(config.debugparanoid && !check_rights(R_ADMIN)) return

	var/returnval = null

	var/procname = input("Proc name", "Proc") as null|text
	if(!procname) return

	if(hastarget)
		if(!target)
			usr << "Your callproc target no longer exists."
			return
		if(!hascall(target, procname))
			usr << "\The [target] has no call [procname]()"
			return

	var/list/arguments = list()
	var/done = 0
	var/current = null

	while(!done)
		if(hastarget && !target)
			usr << "Your callproc target no longer exists."
			return
		switch(input("Type of [arguments.len+1]\th variable", "argument [arguments.len+1]") as null|anything in list(
				"finished", "null", "text", "num", "type", "obj reference", "mob reference",
				"area/turf reference", "icon", "file", "client", "mob's area", "marked datum"))
			if(null)
				return

			if("finished")
				done = 1

			if("null")
				current = null

			if("text")
				current = input("Enter text for [arguments.len+1]\th argument") as null|text
				if(isnull(current)) return

			if("num")
				current = input("Enter number for [arguments.len+1]\th argument") as null|num
				if(isnull(current)) return

			if("type")
				current = input("Select type for [arguments.len+1]\th argument") as null|anything in typesof(/obj, /mob, /area, /turf)
				if(isnull(current)) return

			if("obj reference")
				current = input("Select object for [arguments.len+1]\th argument") as null|obj in world
				if(isnull(current)) return

			if("mob reference")
				current = input("Select mob for [arguments.len+1]\th argument") as null|mob in world
				if(isnull(current)) return

			if("area/turf reference")
				current = input("Select area/turf for [arguments.len+1]\th argument") as null|area|turf in world
				if(isnull(current)) return

			if("icon")
				current = input("Provide icon for [arguments.len+1]\th argument") as null|icon
				if(isnull(current)) return

			if("client")
				current = input("Select client for [arguments.len+1]\th argument") as null|anything in clients
				if(isnull(current)) return

			if("mob's area")
				var/mob/M = input("Select mob to take area for [arguments.len+1]\th argument") as null|mob in world
				if(!M) return
				current = get_area(M)
				if(!current)
					switch(alert("\The [M] appears to not have an area; do you want to pass null instead?",, "Yes", "Cancel"))
						if("Yes")
							; // do nothing
						if("Cancel")
							return

			if("marked datum")
				current = holder.marked_datum
				if(!current)
					switch(alert("You do not currently have a marked datum; do you want to pass null instead?",, "Yes", "Cancel"))
						if("Yes")
							; // do nothing
						if("Cancel")
							return
		if(!done)
			arguments += current

	if(hastarget)
		if(!target)
			usr << "Your callproc target no longer exists."
			return
		log_admin("[key_name(src)] called [target]'s [procname]() with [arguments.len ? "the arguments [list2params(arguments)]" : "no arguments"].")
		if(arguments.len)
			returnval = call(target, procname)(arglist(arguments))
		else
			returnval = call(target, procname)()
	else
		log_admin("[key_name(src)] called [procname]() with [arguments.len ? "the arguments [list2params(arguments)]" : "no arguments"].")
		returnval = call(procname)(arglist(arguments))

	usr << "<span class='info'>[procname]() returned: [isnull(returnval) ? "null" : returnval]</span>"
	feedback_add_details("admin_verb","APC") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!
