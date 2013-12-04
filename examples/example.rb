require 'bundler'
Bundler.setup

require 'ostruct'
require 'roar/representer/json'

def reset_representer(*module_name)
  module_name.each do |mod|
    mod.module_eval do
      @representable_attrs = nil
    end
  end
end


class Song < OpenStruct
end

module SongRepresenter
  include Roar::Representer::JSON

  property :title
end

song = Song.new(title: "Fate").extend(SongRepresenter)
puts song.to_json

song = Song.new.extend(SongRepresenter)
song.from_json('{"title":"Linoleum"}')
puts song.title


# Decorator





reset_representer(SongRepresenter)

module SongRepresenter
  include Roar::Representer::JSON

  property :title
  collection :composers
end


# Collections

song = Song.new(title: "Roxanne", composers: ["Sting", "Stu Copeland"])
song.extend(SongRepresenter)
puts song.to_json

# Nesting

class Album < OpenStruct
end

module AlbumRepresenter
  include Roar::Representer::JSON

  property :title
  collection :songs, extend: SongRepresenter, class: Song
end

album = Album.new(title: "True North", songs: [Song.new(title: "The Island"), Song.new(:title => "Changing Tide")])
album.extend(AlbumRepresenter)
puts album.to_json


# Inline Representers # FIXME: what about collections?

reset_representer(AlbumRepresenter)

module AlbumRepresenter
  include Roar::Representer::JSON

  property :title

  collection :songs, class: Song do
    property :title
  end
end

album = Album.new(title: "True North", songs: [Song.new(title: "The Island"), Song.new(:title => "Changing Tide")])
album.extend(AlbumRepresenter)
puts album.to_json



album = Album.new
album.extend(AlbumRepresenter)
album.from_json('{"title":"True North","songs":[{"title":"The Island"},{"title":"Changing Tide"}]}')
puts album.title
puts album.songs.first.title

# Passing options into link


# parse_strategy: :sync

reset_representer(AlbumRepresenter)

module AlbumRepresenter
  include Roar::Representer::JSON

  property :title

  collection :songs, extend: SongRepresenter, parse_strategy: :sync
end


album = Album.new(title: "True North", songs: [Song.new(title: "The Island"), Song.new(:title => "Changing Tide")])
album.extend(AlbumRepresenter)

puts album.songs.first.object_id
album.from_json('{"title":"True North","songs":[{"title":"Secret Society"},{"title":"Changing Tide"}]}')
puts album.songs.first.title
puts album.songs.first.object_id##

# Hypermedia

reset_representer(SongRepresenter)

module SongRepresenter
  include Roar::Representer::JSON
  include Roar::Representer::Feature::Hypermedia

  property :title

  link :self do
    "http://songs/#{title}"
  end
end

song.extend(SongRepresenter)
puts song.to_json

# Discovering Hypermedia

song = Song.new.extend(SongRepresenter)
song.from_json('{"title":"Roxanne","links":[{"rel":"self","href":"http://songs/Roxanne"}]}')
puts song.links[:self].href

# Media Formats: HAL

require 'roar/representer/json/hal'

module HAL
  module SongRepresenter
    include Roar::Representer::JSON::HAL

    property :title

    link :self do
      "http://songs/#{title}"
    end
  end
end

song.extend(HAL::SongRepresenter)
puts song.to_json

reset_representer(AlbumRepresenter)

module AlbumRepresenter
  include Roar::Representer::JSON::HAL

  property :title

  collection :songs, class: Song, embedded: true do
    property :title
  end
end

album = Album.new(title: "True North", songs: [Song.new(title: "The Island"), Song.new(:title => "Changing Tide")])
album.extend(AlbumRepresenter)
puts album.to_json

# Media Formats: JSON+Collection

require 'roar/representer/json/collection_json'


module Collection
  module SongRepresenter
    include Roar::Representer::JSON::CollectionJSON
    version "1.0"
    href { "http://localhost/songs/" }

    property :title

    items(:class => Song) do
      href { "//songs/#{title}" }

      property :title, :prompt => "Song title"

      link(:download) { "//songs/#{title}.mp3" }
    end

    template do
      property :title, :prompt => "Song title"
    end

    queries do
      link :search do
        {:href => "//search", :data => [{:name => "q", :value => ""}]}
      end
    end
  end
end

song = Song.new(title: "Roxanne")
song.extend(Collection::SongRepresenter)
puts song.to_json



# Client-side
# share in gem, parse existing document.

reset_representer(SongRepresenter)

module SongRepresenter
  include Roar::Representer::JSON
  include Roar::Representer::Feature::Hypermedia

  property :title
  property :id

  link :self do
    "http://songs/#{title}"
  end
end


require 'roar/representer/feature/client'

module Client
  class Song < OpenStruct
    include Roar::Representer::JSON
    include SongRepresenter
    include Roar::Representer::Feature::Client
  end
end

song = Client::Song.new(title: "Roxanne")
song.post("http://localhost:4567/songs", "application/json")
puts song.id


song = Client::Song.new
song.get("http://localhost:4567/songs/1", "application/json")
puts song.title
puts song.links[:self].href



class LinkOptionsCollection < Array

end

module HyperlinkiRepresenter
  include Roar::Representer::JSON

  def to_hash(*)  # setup the link
    # FIXME: why does self.to_s throw a stack level too deep (SystemStackError) ?
    "#{self}"
    # how would the Link instance get access to its Definition in order to execute the block?
  end
end

module Representer
  include Roar::Representer::JSON

  def self.links
    [:self, :next]
  end

  collection :links, :extend => HyperlinkiRepresenter

  def links
    # get link configurations from representable_attrs object.
    #self.representable_attrs.links
    LinkOptionsCollection.new(["self", "next"])
  end
end

puts "".extend(Representer).to_json