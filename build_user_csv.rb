require 'csv'
require 'irb'

train_data = CSV.read('dataset/train.csv')
anime_list = CSV.read('dataset/anime.csv')
test_data = CSV.read('dataset/test.csv')
genre_list = []
studio_list = []
producer_list = []

def clean_list(str)
  str.split(',').map(&:strip).map(&:downcase)
end

anime_genres = Hash.new
anime_data = Hash.new { |h, k| h[k] = Hash.new }
user_data = Hash.new { |h, k| h[k] = Hash.new(0) }
user_score_hist = Hash.new { |h, k| h[k] = Array.new(11, 0) }
genre_count = Hash.new { |h, k| h[k] = Hash.new(0) }
genre_score = Hash.new { |h, k| h[k] = Hash.new(0) }
studio_count = Hash.new { |h, k| h[k] = Hash.new(0) }
studio_score = Hash.new { |h, k| h[k] = Hash.new(0) }
producer_count = Hash.new { |h, k| h[k] = Hash.new(0) }
producer_score = Hash.new { |h, k| h[k] = Hash.new(0) }

def clean_list(str)
  str.split(',').map(&:strip).map(&:downcase)
end

anime_list[1..].each do |row|
  anime_id = row[0]
  genres = clean_list(row[1])
  producers = clean_list(row[6])
  studios = clean_list(row[8])
  plan_to_watch = row[-1].to_i
  dropped = row[-2].to_i
  on_hold = row[-3].to_i
  completed = row[-4].to_i
  watching = row[-5].to_i
  members = row[-6].to_i

  anime_data[anime_id] = {
    genres: genres,
    studios: studios,
    members: members,
    watching: watching,
    completed: completed,
    on_hold: on_hold,
    dropped: dropped,
    plan_to_watch: plan_to_watch,
    producers: producers,
  }
  anime_genres[anime_id] = genres
  genre_list |= genres
  studio_list |= studios
  producer_list |= producers
end

producer_list.sort!
anime_ids = anime_data.keys.sort

train_data[1..].each do |row|
  user_id, anime_id, score = row
  score = score.to_i

  genres = anime_genres[anime_id]
  user_data[user_id][:watch_count] += 1
  user_data[user_id][:review_count] += 1
  user_data[user_id][:total_score] += score
  user_score_hist[user_id][score] += 1
  user_data[user_id][:total_members] += anime_data[anime_id][:members]
  user_data[user_id][:total_watching] += anime_data[anime_id][:watching]
  user_data[user_id][:total_completed] += anime_data[anime_id][:completed]
  user_data[user_id][:total_on_hold] += anime_data[anime_id][:on_hold]
  user_data[user_id][:total_dropped] += anime_data[anime_id][:dropped]
  user_data[user_id][:total_plan_to_watch] += anime_data[anime_id][:plan_to_watch]
  user_data[user_id][anime_id] = score

  anime_data[anime_id][:producers].each do |name|
    producer_count[user_id][name] += 1
    producer_score[user_id][name] += score
  end

  genres.each do |genre|
    user_data[user_id][genre] += 1
    genre_count[user_id][genre] += 1
    genre_score[user_id][genre] += score
  end

  anime_data[anime_id][:studios].each do |name|
    studio_count[user_id][name] += 1
    studio_score[user_id][name] += score
  end
end

test_data[1..].each do |row|
  break
  user_id, anime_id = row

  genres = anime_genres[anime_id]
  user_data[user_id][:watch_count] += 1
  user_data[user_id][:total_members] += anime_data[anime_id][:members]
  user_data[user_id][:total_watching] += anime_data[anime_id][:watching]
  user_data[user_id][:total_completed] += anime_data[anime_id][:completed]
  user_data[user_id][:total_on_hold] += anime_data[anime_id][:on_hold]
  user_data[user_id][:total_dropped] += anime_data[anime_id][:dropped]
  user_data[user_id][:total_plan_to_watch] += anime_data[anime_id][:plan_to_watch]

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
  'average_score',
  'average_members',
  'average_watching',
  'average_completed',
  'average_on_hold',
  'average_dropped',
  'average_plan_to_watch',
  genre_list.map { |genre| genre + "_rate" },
  genre_list.map { |genre| genre + "_score" },
  studio_list.map { |name| name + "_s_score" },
  producer_list.map { |name| name + "_p_score" },
  (1..10).map { |x| "user_#{x}_review_count" },
  (1..10).map { |x| "user_#{x}_review_rate" },
  anime_ids.map { |anime_id| "#{anime_id}_score" },
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
    review_count = data[:review_count]

    file.puts([
      user_id,
      data[:uid],
      data[:watch_count],
      data[:review_count] < 5 ? nil : data[:total_score] / review_count.to_f,
      data[:total_members] / [1.0, data[:watch_count]].max.to_f,
      data[:total_watching] / [1.0, data[:watch_count]].max.to_f,
      data[:total_completed] / [1.0, data[:watch_count]].max.to_f,
      data[:total_on_hold] / [1.0, data[:watch_count]].max.to_f,
      data[:total_dropped] / [1.0, data[:watch_count]].max.to_f,
      data[:total_plan_to_watch] / [1.0, data[:watch_count]].max.to_f,
      genre_list.map { |genre| data[genre] / [1.0, data[:watch_count]].max.to_f },
      genre_list.map { |genre| genre_count[user_id][genre] < 5 ? nil : genre_score[user_id][genre] / genre_count[user_id][genre].to_f },
      studio_list.map { |name| studio_count[user_id][name] < 5 ? nil : studio_score[user_id][name] / studio_count[user_id][name].to_f },
      producer_list.map { |name| producer_count[user_id][name] < 5 ? nil : producer_score[user_id][name] / producer_count[user_id][name].to_f },
      (1..10).map { |x| user_score_hist[user_id][x] },
      (1..10).map { |x| review_count < 5 ? nil : user_score_hist[user_id][x] / review_count.to_f },
      anime_ids.map { |anime_id| data[anime_id] == 0 ? nil : data[anime_id] },
    ].flatten.to_csv)
  end
end
