require 'csv'
require 'irb'

train_data = CSV.read('dataset/train.csv')
anime_list = CSV.read('dataset/anime.csv')
test_data = CSV.read('dataset/test.csv')
genre_list = []

anime_genres = Hash.new
anime_data = Hash.new { |h, k| h[k] = Hash.new }
user_data = Hash.new { |h, k| h[k] = Hash.new(0) }

anime_list[1..].each do |row|
  anime_id = row[0]
  plan_to_watch = row[-1].to_i
  dropped = row[-2].to_i
  on_hold = row[-3].to_i
  completed = row[-4].to_i
  watching = row[-5].to_i
  genres = row[1].split(',').map(&:strip).map(&:downcase)

  anime_data[anime_id] = {
    plan_to_watch: plan_to_watch,
    dropped: dropped,
    on_hold: on_hold,
    completed: completed,
    watching: watching,
  }
  anime_genres[anime_id] = genres
  genre_list |= genres
end

train_data[1..].each do |row|
  user_id, anime_id, score = row

  genres = anime_genres[anime_id]
  user_data[user_id][:watch_count] += 1

  genres.each do |genre|
    user_data[user_id][genre] += 1
  end
end

test_data[1..].each do |row|
  user_id, anime_id = row

  genres = anime_genres[anime_id]
  user_data[user_id][:watch_count] += 1

  genres.each do |genre|
    user_data[user_id][genre] += 1
  end
end

genre_list = genre_list.map(&:downcase)
genre_list.sort!
genre_idx = Hash.new
genre_list.each_with_index do |name, id|
  genre_idx[name] = id
end

user_data.keys.each_with_index do |id, uid|
  user_data[id][:uid] = uid
end

labels = [
  'user_id',
  'uid',
  'watch_count',
  genre_list.map { |genre| genre + "_rate" }
].flatten

user_watched_category = Hash.new { |h, k| h[k] = Array.new(genre_list.size, 0) }
user_watched_counter = Hash.new { |h, k| h[k] = Array.new(genre_list.size, 0) }

train_data[1..].each do |row|
  user_id, anime_id, score = row

  anime_genres[anime_id].each do |name|
    id = genre_idx[name]
    user_watched_category[user_id][id] = 1
    user_watched_counter[user_id][id] += 1
  end
end

File.open('dataset/users.csv', 'w') do |file|
  file.puts(labels.join(','))

  user_data.each do |user_id, data|
    watch_count = genre_list.map { |genre| [genre, data[genre]] }
    watch_count.sort_by! { |_, cnt| -cnt }

    file.puts([
      user_id,
      data[:uid],
      data[:watch_count],
      genre_list.map { |genre| data[genre] / [1.0, data[:watch_count]].max.to_f }
    ].flatten.to_csv)
  end
end
