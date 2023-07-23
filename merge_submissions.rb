require 'csv'

output_dir = 'outputs/tutorial-1'

seen_csv = 'submission_for_seen.csv'
unseen_csv = 'best_submission.csv'

train_data = CSV.read('dataset/train.csv')
test_data = CSV.read('dataset/test.csv')

train_user_ids = train_data.map { |row| row[0] }.tally
test_user_ids = test_data.map { |row| row[0] }.tally

csv_seen = CSV.read(File.join(output_dir, seen_csv))
csv_unseen = CSV.read(File.join(output_dir, unseen_csv))

File.open('submission.csv', 'w') do |file|
  file.puts("score")

  test_data[1..].each.with_index(1) do |row, idx|
    user_id, anime_id = row

    if train_user_ids[user_id]
      file.puts(csv_seen[idx].first.to_f.clamp(1.0, 10.0))
    else
      file.puts(csv_unseen[idx].first.to_f.clamp(1.0, 10.0))
    end
  end
end

