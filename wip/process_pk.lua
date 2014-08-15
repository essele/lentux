#!./luajit

function usage()
	print("Usage: " .. arg[0] .. " <package_file>")
	os.exit(1)
end

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
			print(string.format("%s: %s", curkey, v))
			goto continue
		end

		-- carry-on --
		v = line:match("^%s+([^%s].*)$")
		if(v) then
			if(not curkey) then
				err = string.format("Illegal continuation at line %d, ignoring", ln)
				break;
			end
			table.insert(rc[curkey], v)
			print(string.format("%s: %s", curkey, v))
			goto continue
		end

		-- just blanks --
		if(line:match("^%s*$")) then
			curkey = nil
			goto continue
		end

		-- must be an error --
		if(true) then
			err = string.format("garbage at line %d, ignoring", ln)
			break
		end

::continue::
	end

	f:close()
	if(err) then return nil, err end
	return rc
end

--
-- Expand any variables for the given key, note that the order the
-- expansion is done is relevant, there is no recursion
--
function var_expand(vars, key)
	local items = vars[key]
	local new = {}

	for i, v in ipairs(items) do
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
-- For items that are supposed to be single (i.e. not lists) then
-- we can check, and if valid we can change over to a string.
--
function validate_strings(vars, list)
	local err = 0

	for _, i in ipairs(list) do
		if(vars[i]) then
			if(#vars[i] ~= 1) then
				print("Expect only one item for: " .. i)
				err = 1
			else
				vars[i] = vars[i][1]
			end
		end
	end
	return err
end


if(not arg[1]) then usage() end

pkg, err = read_pk(arg[1])
if(not pkg) then
	print(arg[0] .. ": " .. err)
	os.exit(1)
end

print("source=" .. table.concat(pkg.source, "\n"))

var_expand(pkg, "source")
var_expand(pkg, "fred")
print("--")

print("fred=" .. table.concat(pkg.fred, "\n"))

validate_strings(pkg, { "source", "name", "version" })

print("source=" .. pkg.source)

