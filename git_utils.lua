-- local folderOfThisFile = (...):match("(.-)[^%.]+$") -- returns 'lib.foo.'
-- local json = require(folderOfThisFile .. 'libs.json')
local json = require ".libs.lua.json"

function t_len(T)
   local count = 0
   for _ in pairs(T) do count = count + 1 end
   return count
end

function load_stored_args() 
    local state = fs.open("/.git/state", "r")
    local raw = state.readAll()
    local content
    if raw == "" then
        content = "{}"
    end
    
    content = json.parse(raw)
    print(content)
    print(json.stringify(content))
    state.close()
    return content
end

function ls_into_repo(path)
    local response = git_ls(path)
    local res = json.parse(response)
    local res_size = t_len(res)
    local parsed = {}
    for file_idx = 1, res_size do
        local data = res[file_idx]
        local p_data = filter_relevant_fields(data)
        parsed[p_data['path']] = p_data

        if p_data['type'] == 'dir' then
            local r_files = ls_into_repo(p_data['path'])
            for i, v in pairs(r_files) do
                parsed[i] = v
            end
        end
    end

    return parsed
end

function remove_filter_path(raw_path)
    local res = raw_path
    if paths ~= nil then
        res = string.gsub(raw_path, paths, "")
    end
    return res
end

function pull()
    local parsed = ls_into_repo(paths)
    local cur_dir = shell.dir()
    local res_size = t_len(parsed)
    for i, v in pairs(parsed) do
        local data = v
        
        local target_path = fs.combine(cur_dir, remove_filter_path(data['path']))
        local source_path = data['path']
        
        shell.run("git", "get", author, proj, branch, source_path, target_path)
    end
end

function pullDir(table)
   local res_size = t_len(parsed)
    for file_idx = 1, res_size do
        local data = parsed[file_idx]
        local target_path = fs.combine(cur_dir, data['path'])
        local source_path = data['path']
        
        shell.run("git", "get", author, proj, branch, source_path, target_path)
    end
end

function filter_relevant_fields(raw)
    local parsed = {}
    parsed['path'] = raw['path']
    parsed['name'] = raw['name']
    parsed['type'] = raw['type']
   return parsed
end

tArgs = {...}

storedArgs = load_stored_args()

if  #tArgs == 0 then
   print('Usage: git [get/pull/ls] [git owner] [repository] [branch] [path] {file-name}')
   return false
end

if  #tArgs == 1 then
    if tArgs[1] == "ls" then
        
    else
        print('Usage: git [get/pull/ls] [git owner] [repository] [branch] [path] {file-name}')
        return false
    end
end

option = tArgs[1]
author = tArgs[2]
proj = tArgs[3]
branch = tArgs[4]
paths = tArgs[5]
saveName = tArgs[6]

function requestObject(url)
    if not url then error('Incorrect statement!') end
    http.request(url)
    local requesting = true
    while requesting do
        local event, url, sourceText = os.pullEvent()
        if event == "http_success" then
            print("Fetch success!")
            local respondedText = sourceText.readAll()
            requesting = false
            return respondedText
        elseif event == "http_failure" then
            print("Fetch failed! Please check values or non-existent project!")
            requesting = false
            return false
        end
    end
end

function compileURL(auth,pro,bran,pat)
    baseURL = 'https://api.github.com/repos/'..auth..'/'..pro..'/contents/'..pat
    print(".../"..auth..'/'..pro..'/contents/'..pat)
    return baseURL
end

function git_ls(p)
    if p == nil then
        p = ''
    end

    return requestObject(compileURL(author, proj, branch, p))
end

if option == 'get' then
    print('working on it...')
elseif option == 'ls' then
    local res = ls_into_repo(paths)
    if not res then return end

    local res_size = t_len(res)
    print('')
    print('N of files: '..res_size)
    print('-----')
    for i, v in pairs(res) do
        local path = v['path']
        if v['type'] == 'dir' then
            print(path..'/')
        else
            print(path)
        end
    end
elseif option == 'pull' then
    pull()
elseif option == status then
    load_stored_args()
end
