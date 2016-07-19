#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#               2016 Scarlett Clark <sgclark@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

$:.unshift('/var/lib/jenkins/ci-tooling')

require '/var/lib/jenkins/ci-tooling/nci/lib/setup_repo.rb'
require_relative 'lib/appstreamer.rb'
require_relative 'lib/snap.rb'
require_relative 'lib/snapcraft.rb'

runtimedeps = %w(plasma-integration)

###

snap = Snap.new
snap.name = 'kcalc'
snap.version = '16.04.1'
snap.stagedepends = `apt-cache depends #{snap.name} | awk '/Depends:/{print$2}' | sed -e 's/Depends:/""/' | sed -e '/</ d'`.split("\n")
snap.stagedepends += `apt-cache depends #{snap.name} | awk '/Recommends:/{print$2}' | sed -e 's/Recommends:/""/' | sed -e '/</ d'`.split("\n")

runtimedeps.each do |dep|
  snap.stagedepends.push dep
  runtimedep = `apt-cache depends #{dep} | awk '/Depends:/{print$2}' | sed -e '/</ d' | sed -e 's/ |Depends:/""/' | sed -e 's/  Depends:/""/'`.split("\n")
  runtimedep.each do |dep|
    snap.stagedepends |= [dep]
  end
  runtimerec = `apt-cache depends #{dep} | awk '/Recommends:/{print$2}' | sed -e '/</ d' | sed -e 's/ |Recommends:/""/' | sed -e 's/  Depends:/""/'`.split("\n")
  runtimerec.each do |dep|
    snap.stagedepends |= [dep]
  end
end
snap.stagedepends.sort!
p snap.stagedepends

desktopfile = "org.kde.#{snap.name}.desktop"
helpdesktopfile = 'org.kde.Help.desktop'

### appstream

appstreamer = AppStreamer.new(desktopfile)
appstreamer.expand(snap)
icon_url = appstreamer.icon_url
snap.apps = [Snap::App.new(snap.name)]
File.write('snapcraft/snapcraft.yaml', snap.render)

##

Dir.chdir('snapcraft')
Snapcraft.pull

desktop_url = "parts/#{snap.name}/install/usr/share/applications/#{desktopfile}"
help_desktop_url = "parts/#{snap.name}/install/usr/share/applications/#{helpdesktopfile}"

FileUtils.mkpath('setup/gui/')
FileUtils.cp(icon_url, 'setup/gui/icon') if icon_url
FileUtils.cp(desktop_url, "setup/gui/#{desktopfile}") if desktop_url
if File.exist?(help_desktop_url)
  FileUtils.cp(help_desktop_url, "setup/gui/#{helpdesktopfile}")
end

Snapcraft.run

Dir.glob('*.snap') do |f|
  system('zsyncmake', f) || raise
end
