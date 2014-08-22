#!./luajit

--
-- Given a simple .pk format file we process the file, do some rudimentary
-- syntax and required-fields checking and expand variables.
--
-- We build a set of more complete variables (by combining others)
--
-- Then we produce a small makefile that does the right thing.
--

local required_fields = {
	"name", "source-url", "version"
}

local string_fields = {
	"name", "version", "source-archive", "source-dir",
	"NAME"
}

local pre_expand_template = {
	["install-dir"] =		{ "$(BASE_DIR)/output/target" },
	["install-prefix"] =	{ "/usr" },
	["configure"] = 		{ "configure --prefix=/usr" },
	["make"] = 				{ "make" },
	["install"] = 			{ "make DESTDIR=$[install-dir]" },
	["source-archive"] =	{ "$[name]-$[version].tar.gz" },
	["source-dir"] =		{ "$[name]-$[version]" },
	["template"] =			{ "autotools" },
	["template-dir"] = 		{ "." },
	["template-file"] = 	{ "$[template-dir]/$[template].tmpl" }
}

local unpackers = {
	[".tar.gz"] = "tar -C $(BUILD_DIR) -zxf $<",
	[".tgz"] = "tar -C $(BUILD_DIR) -zxf $<",
}

local post_expand_template = {
	["NAME"] = function(v) return { v["name"][1]:upper() } end,
	["FRED"] = function(v) return { "this should be fred" } end,
	["unpack-cmd"] = function(v) return { find_unpacker(v["source-archive"][1]) } end
}

--
-- Basic usage function
--
function usage()
	print("Usage: " .. arg[0] .. " [-t <template_dir>] <package_file>")
	os.exit(1)
end

--
-- Find an unpack command based on the file extension
--
function find_unpacker(filename)
	for k,v in pairs(unpackers) do
		if(filename:sub(-#k) == k) then return v end
	end
	return "$(error no unpacker known for " .. filename .. ")"
end

--
-- Simple table copy function
--
function table_copy(t)
	local rc = {}

	for k,v in pairs(t) do
		if(type(v) == "table") then
			rc[k] = table_copy(v)
		else
			rc[k] = v
		end
	end
	return rc
end


--
-- Read the pk file and create a table containing all the info
--
function read_pk(filename)
	local f = io.open(filename)
	local err
	if(not f) then
		return nil, "Unable to open file: " .. filename
	end

	local rc = {}
	local curkey
	local ln = 0

	while(true) do
		local line = f:read()
		local k, v
		if(not line) then break end

		ln = ln + 1

		-- key: value -- 
		k, v = line:match("^([^:%s]+):%s+(.*)$")
		if(k) then
			curkey = k
			if(not rc[curkey]) then rc[curkey] = {} end
			table.insert(rc[curkey], v)
			goto continue
		end

		-- carry-on --
		v = line:match("^%s+([^%s].*)$")
		if(v) then
			if(not curkey) then
				err = string.format("Illegal continuation at line %d", ln)
				break;
			end
			table.insert(rc[curkey], v)
			goto continue
		end

		-- if we didn't start with an indent, then we clear curkey
		curkey = nil

		-- handle <include>
		if(line:match("^<include>")) then
			rc["include"] = {}
			while(true) do
				line = f:read()
				if(not line) then break end
				table.insert(rc["include"], line)
			end
			goto continue
		end

		-- just blanks --
		if(line:match("^%s*$")) then goto continue end

		-- comments
		if(line:match("^#")) then goto continue end

		-- must be an error --
		if(true) then
			err = string.format("garbage at line %d", ln)
			break
		end

::continue::
	end

	f:close()
	if(err) then return nil, err end
	return rc
end

--
-- Simple return an iterator of all variables referenced by the given
-- key, this is so that we can check for dependencies and do them
-- in the right order
--
function referenced_variables(vars, key)
	local rc = {}
	local last

	for i, v in ipairs(vars[key]) do
		for var in v:gmatch("[@$]%[([^]]+)%]") do
			rc[var] = 1
		end
	end
	return function()
		last = next(rc, last)
		return last
	end
end

--
-- Expand any variables for the given key (we assume dependencies have
-- been handled before calling)
--
function expand_variable(vars, key)
	local new = {}

	for i, v in ipairs(vars[key]) do
		local newitem

		-- expansion using $[] expands to space separated (single line)
		newitem = v:gsub("%$%[([^]]+)%]", function(s)
			return (vars[s] and table.concat(vars[s], " ")) or ""
		end)

		-- expansion using @[] expands to multiple lines
		local akey = newitem:match("@%[([^]]+)%]")
		if(akey) then
			for _,elem in ipairs(vars[akey] or {}) do
				table.insert(new, (newitem:gsub("@%[[^]]+%]", elem)))
			end
		else
			table.insert(new, newitem)
		end
	end
	-- if we don't have items then we remove the key
	vars[key] = (new[1] and new) or nil
end

--
-- Loop through expanding all the variables, we need to keep going until
-- we have done no work
--
function expand_all_variables(vars)
	local done = {}

	repeat 	
		local processed = 0
		for k, v in pairs(vars) do
			if(done[k]) then goto continue end

			-- see if all our referenced variables have been done, if not
			-- we have to skip this one for now
			for r in referenced_variables(vars, k) do
				if(not done[r]) then goto continue end
			end

			-- ok, we can expand
			expand_variable(vars, k)
			done[k] = 1
			processed = 1
::continue::
		end
	until(processed == 0)
end


--
-- For items that are supposed to be single (i.e. not lists) then
-- we can check, and if valid we can change over to a string.
--
function strings_are_ok(vars, list)
	for _, i in ipairs(list) do
		if(vars[i]) then
			if(#vars[i] ~= 1) then
				print("Multiple items for: " .. i)
				return false
			else
				vars[i] = vars[i][1]
			end
		end
	end
	return true
end

--
-- Check for required fields
--
function all_required_ok(vars, reqd)
	for _,i in ipairs(reqd) do
		if(not vars[i]) then
			print("Missing variable: " .. i)
			return false
		end
	end
	return true
end

--
-- Add any non-defined variables (inc. function calls)
--
function add_variables(vars, actions)
	for k,v in pairs(actions) do
		if(not vars[k]) then
			if(type(v) == "function") then
				vars[k] = v(vars)
			else
				vars[k] = table_copy(v)
			end
		end
	end
end

--
-- Dump the vars in a human readable form
--
function dump(vars)
	for k, v in pairs(vars) do
		if(type(v) == "table") then
			for i,elem in ipairs(v) do
				if(i == 1) then
					print(k .. ": [ " .. elem .. " ]")
				else
					print(string.rep(" ",#k+1) .. " [ " .. elem .. " ]")
				end
			end
		else
			print(k .. ": " .. v)
		end
	end
end

--
-- Read a file into a given field
--
function read_file(filename, vars, key)
	local data = {}
	local file = io.open(filename)

	if(not file) then
		print("Unable to open file: " .. filename)
		return false
	end

	for l in file:lines() do
		table.insert(data, l)
	end
	vars[key] = data
	return true
end


--
-- Read the command line
--
local template_dir = "."
local pkg_file
if(#arg == 3 and arg[1] == "-t") then
	template_dir = arg[2]
	pkg_file = arg[3]
elseif(#arg == 1) then
	pkg_file = arg[1]
else	
	usage()
end

--
-- Read the file and do basic processing...
--
pkg, err = read_pk(pkg_file)
if(not pkg) then
	print(arg[0] .. ": " .. err)
	os.exit(1)
end

--
-- Add in the template variables in the pre-expand stage
--
add_variables(pkg, pre_expand_template)

--
-- Add our template directory
--
pkg["template-dir"] = { template_dir }

--
-- Now we can expand any embedded variables
--
expand_all_variables(pkg)

--
-- Add in the template variables for the post-expand stage
--
add_variables(pkg, post_expand_template)

--
-- Read in our template file
--
if(not read_file(pkg["template-file"][1], pkg, ".template")) then os.exit(1) end

--
-- Expand any variables in the template
--
expand_variable(pkg, ".template")



--
-- Make sure we now have all required variables and strings are ok
--
if(not all_required_ok(pkg, required_fields)) then os.exit(1) end
if(not strings_are_ok(pkg, string_fields)) then os.exit(1) end

--
--
--
dump(pkg)


