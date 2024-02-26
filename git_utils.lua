-- v2
local json = require ".libs.lua.json"

-- ########################
-- # Function definitions #
-- ########################


local function deleteIfExists(path)
    local res = shell.resolve(path)
    if fs.exists(res) then
        fs.delete(res)
    end
end

function list_usages()
    print('Usage: git get [git_owner repository branch] {path} {file-name}')
    print('Usage: git pull [git_owner repository branch] [path]')
    print('Usage: git ls [git_owner repository branch] [path]')
    print('Usage: git status [git_owner repository branch]')
    print('Usage: git owner [git_owner]')
    print('Usage: git repo [repository]')
    print('Usage: git branch [branch]')
end

function print_sorted(m_table)
    local tkeys = {}
    for k in pairs(m_table) do table.insert(tkeys, k) end
    table.sort(tkeys)
    for _, k in ipairs(tkeys) do
        local val = m_table[k]
        if val['type'] ~= 'dir' then
            print(val['path'])
        end
    end
end

function t_len(T)
   local count = 0
   for _ in pairs(T) do count = count + 1 end
   return count
end

function load_stored_args()
    local state = fs.open("/.git/state", "r")
    local raw = state.readAll()
    local content = raw
    if raw == "" or raw == "\n" then
        content = "{}"
    end
    
    content = json.parse(content)
    state.close()
    return content
end

function write_value_state(field, value)
    local state = fs.open("/.git/state", "r")
    local raw = state.readAll()
    local content = raw
    if raw == "" or raw == "\n" then
        content = "{}"
    end
    
    content = json.parse(content)
    state.close()


    content[field] = value
    local state = fs.open("/.git/state", "w")
    state.write(json.stringify(content))
    state.close()

    return content
end

function ls_into_repo(path)
    local response = git_ls(path)
    local res = json.parse(response)
    local parsed = {}
    for file_idx, file_data in pairs(res) do
        local data = file_data
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
        
        local target_path = fs.combine(remove_filter_path(shell.dir(), data['path']))
        local source_path = data['path']
        
        shell.run("git", "get", author, proj, branch, source_path, target_path)
    end
end

function get(source_path, target_path)
    local source = compileGet(author, proj, branch, source_path)
    deleteIfExists(target_path)
    shell.run("wget", source, target_path)
end

function git_ls(p)
    if p == nil then
        p = ''
    end

    return requestObject(compileURL(author, proj, branch, p))
end

function pullDir(table)
    local res_size = t_len(parsed)
     for file_idx = 1, res_size do
         local data = parsed[file_idx]
         local target_path = fs.combine(cur_dir, data['path'])
         local source_path = data['path']
         
         get(source_path, target_path)
     end
 end

 function filter_relevant_fields(raw)
    local parsed = {}
    parsed['path'] = raw['path']
    parsed['name'] = raw['name']
    parsed['type'] = raw['type']
   return parsed
end

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
    return baseURL
end

function compileGet(auth, pro, bran, pat)
    return 'https://raw.githubusercontent.com/'..auth..'/'..pro..'/'..bran..'/'..pat
end



-- #########################
-- # Actual program starts #
-- #########################

tArgs = {...}

storedArgs = load_stored_args()

if #tArgs == 0 then
    list_usages()
    return false
end

valid_opts = {get = true, pull = true, ls = true,  status = true, branch = true, owner = true, repo = true}

option = tArgs[1]

if valid_opts[option] == nil then
    list_usages()
    return false;
end


-- Fill paramters
if option == "get" then
    if #tArgs ~= 3 and #tArgs ~= 6 then
        list_usages()
        return false
    end

    if #tArgs == 3 then
        paths = tArgs[2]
        saveName = tArgs[3]
    else
        author = tArgs[2]
        proj = tArgs[3]
        branch = tArgs[4]
        paths = tArgs[5]
        saveName = tArgs[6]
    end

elseif option == "pull" or option == "ls" then
    if #tArgs ~= 1 and #tArgs ~= 2 and #tArgs ~= 4 and #tArgs ~= 5 then
        list_usages()
        return false
    end

    if #tArgs == 2 then
        paths = tArgs[2]
    elseif #tArgs == 4 then
        author = tArgs[2]
        proj = tArgs[3]
        branch = tArgs[4]

    elseif #tArgs ~= 5 then
        author = tArgs[2]
        proj = tArgs[3]
        branch = tArgs[4]
        paths = tArgs[5]
    end

elseif option == "owner" or option == "repo" or option == "branch" then
    if #tArgs ~= 1 and #tArgs ~= 2 then
        list_usages()
        return false
    end

    if  #tArgs == 2 then 
        if option == "owner" then
            author = tArgs[2]
        elseif option == "repo" then
            proj = tArgs[2]
        elseif option == "branch" then
            branch = tArgs[2]
        end
    end

elseif option == "status" then
    if #tArgs ~= 1 and #tArgs ~= 4 then
        list_usages()
        return false
    end

    if  #tArgs == 4 then 
        author = tArgs[2]
        proj = tArgs[3]
        branch = tArgs[4]
    end
end

if author == nil then
    if storedArgs["owner"] == nil then
        print("Repo owner not defined")
        return false
    end

    author = storedArgs["owner"]
end

if proj == nil then
    if storedArgs["repo"] == nil then
        print("Repo not defined")
        return false
    end
    proj = storedArgs["repo"]
end

if branch == nil then
    if storedArgs["branch"] == nil then
        print("Branch not defined")
        return false
    end
    branch = storedArgs["branch"]
end



if option == 'get' then
    get(paths, saveName)
elseif option == 'ls' then
    local res = ls_into_repo(paths)
    if not res then return end

    local res_size = t_len(res)
    print('')
    print_sorted(res)
elseif option == 'pull' then
    pull()
elseif option == "owner" then
    if #tArgs == 2 then
        write_value_state("owner", author)
        print(author..">"..proj..">"..branch)
    else
        print(author)
    end

elseif option == "repo" then
    if #tArgs == 2 then
        write_value_state("repo", proj)
        print(author..">"..proj..">"..branch)
    else
        print(proj)
    end

elseif option == "branch" then
    if #tArgs == 2 then
        write_value_state("branch", branch)
        print(author..">"..proj..">"..branch)
    else
        print(branch)
    end

elseif option == "status" then
    if #tArgs == 4 then
        write_value_state("owner", author)
        write_value_state("repo", proj)
        write_value_state("branch", branch)
    end

    print(author..">"..proj..">"..branch)
end
