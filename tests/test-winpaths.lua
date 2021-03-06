--[[
Copyright 2015 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]
local los = require('los')

if los.type() ~= 'win32' then return end
local win_paths = require('../util/win_paths')

require('tap')(function(test)
  test('Windows Folder Paths', function()
    local path
    path = win_paths.GetKnownFolderPath(win_paths.FOLDERID_ProgramData)
    p('FOLDERID_ProgramData', path)
    assert(path ~= nil)
    path = win_paths.GetKnownFolderPath(win_paths.FOLDERID_ProgramFiles)
    p('FOLDERID_ProgramFiles', path)
    assert(path ~= nil)
  end)

  test('Windows Executable Assocations', function()
    assert(win_paths.GetAssociatedExe('.ps1', '0'))
  end)
end)

