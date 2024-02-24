local json = require "libs.json"

function t_len(T)
   local count = 0
   for _ in pairs(T) do count = count + 1 end
   return count
end

tArgs = {...}

if  #tArgs == 0 then
   print('Usage: git [get/pull/ls] [git owner] [repository] [branch] [path] {file-name}')
   return false
end

option = tArgs[1]
author = tArgs[2]
proj = tArgs[3]
branch = tArgs[4]
paths = tArgs[5]
saveName = tArgs[6]


function requestObject(url)
    if not url then error('Incorrect statement!') end
    write('Fetching: '..url..'... ')
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

function git_ls()
    if paths == nil then
        paths = ''
    end

    return requestObject(compileURL(author, proj, branch, paths))
end

if option == 'get' then
    print('working on it...')
elseif option == 'ls' then
    local response = git_ls()
    local res = json.parse(response)

    local res_size = t_len(res)
    for file_idx = 1, res_size do
        local data = res[file_idx]
        local path = data['path']
        if data['type'] == 'dir' then
            print(path..'/')
        else
            print(path)
        end
    end

   print('N of files: '..res_size)
end
