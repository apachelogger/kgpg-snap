#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require 'erb'
require 'yaml'

class Snap
  class App
    attr_accessor :name
    attr_accessor :command
    attr_accessor :plugs

    def initialize(name)
      @name = name
      @command = "qt5-launch usr/bin/#{name}"
      @plugs = %w(x11 unity7 home opengl network network-bind network-manager)
    end

    def to_yaml(options = nil)
      { @name => { 'command' => @command, 'plugs' => @plugs } }.to_yaml(options)
    end
  end

  attr_accessor :name
  attr_accessor :version
  attr_accessor :summary
  attr_accessor :description
  attr_accessor :apps

  def render
    ERB.new(File.read('snapcraft/snapcraft.yaml.erb')).result(binding)
  end
end

### appstream
require 'fileutils'
require 'gir_ffi'

GirFFI.setup(:AppStream)

db = AppStream::Database.new
db.open
component = db.component_by_id('org.kde.konsole.desktop')
component.name

icon_url = nil
component.icons.each do |icon|
  puts icon.kind
  puts icon.url
  next unless icon.kind == :cached
  icon_url = icon.url
end
p component.summary
p component.description

FileUtils.cp(icon_url, 'snapcraft/gui/icon') if icon_url
###

snap = Snap.new
snap.name = 'konsole'
snap.version = '16.04.1'
snap.summary = component.summary
snap.description = component.description
snap.apps = [Snap::App.new('konsole')]
File.write('snapcraft/snapcraft.yaml', snap.render)

Dir.chdir('snapcraft')
system('snapcraft') || raise
Dir.glob('*.snap') do |f|
  system('zsyncmake', f) || raise
end
