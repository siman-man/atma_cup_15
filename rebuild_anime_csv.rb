require 'csv'
require 'irb'

train_data = CSV.read('dataset/train.csv')
anime_list = CSV.read('dataset/anime.csv')
test_data = CSV.read('dataset/test.csv')
genre_list = []

anime_genres = Hash.new
anime_data = Hash.new { |h, k| h[k] = Hash.new }
anime_score_histgram = Hash.new { |h, k| h[k] = Array.new(11, 0) }
studio_list = []
producer_list = []

def clean_list(str)
  str.split(',').map(&:strip).map(&:downcase)
end

review_count = Hash.new(0)
total_score = Hash.new(0)

train_data[1..].each do |row|
  user_id, anime_id, score = row
  score = score.to_i

  review_count[anime_id] += 1
  total_score[anime_id] += score
  anime_score_histgram[anime_id][score] += 1
end

anime_list[1..].each do |row|
  anime_id = row[0]
  producers = row[6]
  studios = row[8]
  plan_to_watch = row[-1].to_i
  dropped = row[-2].to_i
  on_hold = row[-3].to_i
  completed = row[-4].to_i
  watching = row[-5].to_i
  members = row[-6].to_i
  genres = clean_list(row[1])

  studio_list << clean_list(studios)
  producer_list << clean_list(producers)

  anime_data[anime_id] = {
    plan_to_watch: plan_to_watch,
    dropped: dropped,
    on_hold: on_hold,
    completed: completed,
    watching: watching,
    drop_rate: dropped / [1.0, watching.to_f].max,
    hold_rate: on_hold / [1.0, watching.to_f].max,
    comp_rate: completed / [1.0, members.to_f].max,
    review_score: review_count[anime_id] == 0 ? nil : total_score[anime_id] / review_count[anime_id].to_f,
    review_count: review_count[anime_id],
  }
  anime_genres[anime_id] = genres
  genre_list |= genres
end

studio_list = studio_list.flatten.uniq.sort
studio_ids = Hash.new
studio_list.each.with_index(1) do |name, id|
  studio_ids[name] = id
end

producer_list = producer_list.flatten.uniq.sort
producer_ids = Hash.new
producer_list.each.with_index(1) do |name, id|
  producer_ids[name] = id
end

genre_list = genre_list.map(&:downcase)
genre_list.sort!
genre_idx = Hash.new
genre_list.each_with_index do |name, id|
  genre_idx[name] = id
end

labels = [
  anime_list[0],
  'main_producer',
  'main_studio',
  'comp_rate',
  'drop_rate',
  'hold_rate',
  'review_score',
  'review_count',
  (1..10).map { |x| "anime_#{x}_review_count" },
  (1..10).map { |x| "anime_#{x}_review_rate" },
  genre_list,
].flatten

File.open('dataset/anime_rebuild.csv', 'w') do |file|
  file.puts(labels.join(','))

  anime_list[1..].each do |row|
    anime_id = row[0]
    genres = clean_list(row[1])
    producers = clean_list(row[6])
    studios = clean_list(row[8])
    check_list = genre_list.map { |genre| genres.include?(genre) ? 1 : 0 }
    review_count = anime_data[anime_id][:review_count]

    row << producer_ids[producers.flatten.first]
    row << studio_ids[studios.flatten.first]
    row << anime_data[anime_id][:comp_rate]
    row << anime_data[anime_id][:drop_rate]
    row << anime_data[anime_id][:hold_rate]
    row << anime_data[anime_id][:review_score]
    row << review_count
    row.concat((1..10).map { |x| anime_score_histgram[anime_id][x] })
    row.concat((1..10).map { |x| review_count == 0 ? nil : anime_score_histgram[anime_id][x] / review_count.to_f })
    row.concat(check_list)

    if labels.size != row.size
      raise
    end

    file.puts(row.to_csv)
  end
end
