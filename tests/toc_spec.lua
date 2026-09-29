-- Validates both TOC files: listed files exist, and Forever-only files stay out of the TBC build

local function readToc(path)
    local f = assert(io.open(path, "r"), "missing " .. path)
    local meta, files = {}, {}
    for line in f:lines() do
        line = line:gsub("\r$", "")
        local key, value = line:match("^##%s*([%w%-]+):%s*(.-)%s*$")
        if key then
            meta[key] = value
        elseif line ~= "" and not line:match("^#") then
            files[#files + 1] = line:gsub("\\", "/")
        end
    end
    f:close()
    return meta, files
end

local function fileExists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

describe("TOC files", function()
    local tbcMeta, tbcFiles = readToc("Castborn.toc")
    local foreverMeta, foreverFiles = readToc("Castborn_Camelot.toc")

    it("targets the right interface versions", function()
        assert.are.equal("20505", tbcMeta.Interface)
        assert.are.equal("16001", foreverMeta.Interface)
    end)

    it("shares saved variables between flavours", function()
        assert.are.equal(tbcMeta.SavedVariables, foreverMeta.SavedVariables)
    end)

    it("lists only files that exist", function()
        for _, path in ipairs(tbcFiles) do
            assert.is_true(fileExists(path), "Castborn.toc lists missing file " .. path)
        end
        for _, path in ipairs(foreverFiles) do
            assert.is_true(fileExists(path), "Castborn_Camelot.toc lists missing file " .. path)
        end
    end)

    it("keeps Forever-only files out of the TBC build", function()
        for _, path in ipairs(tbcFiles) do
            assert.is_nil(path:match("_Forever%.lua$"), "Castborn.toc lists Forever file " .. path)
        end
    end)

    it("loads Core.lua first in both builds", function()
        assert.are.equal("Core.lua", tbcFiles[1])
        assert.are.equal("Core.lua", foreverFiles[1])
    end)
end)
