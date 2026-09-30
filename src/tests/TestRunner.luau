--!strict
-- Runs every ModuleScript under this folder whose name ends in ".spec".
-- A spec module returns { [testName]: () -> () }; a test fails if it errors.

local TestRunner = {}

function TestRunner.run(filter: string?): string
	local passed, failed = 0, 0
	local failures = {}

	for _, module in script.Parent:GetDescendants() do
		if not module:IsA("ModuleScript") or not module.Name:match("%.spec$") then
			continue
		end
		if filter and not module.Name:find(filter, 1, true) then
			continue
		end

		local loaded, suite = pcall(require, module)
		if not loaded then
			failed += 1
			table.insert(failures, `FAIL {module.Name} (load): {suite}`)
			continue
		end
		if typeof(suite) ~= "table" then
			failed += 1
			table.insert(failures, `FAIL {module.Name} (load): returned a {typeof(suite)}, not a table of tests`)
			continue
		end

		local names = {}
		for name in suite do
			table.insert(names, name)
		end
		table.sort(names)

		for _, name in names do
			local ok, err = pcall(suite[name])
			if ok then
				passed += 1
			else
				failed += 1
				table.insert(failures, `FAIL {module.Name} > {name}: {err}`)
			end
		end
	end

	table.insert(failures, 1, `{passed} passed, {failed} failed`)
	return table.concat(failures, "\n")
end

return TestRunner
