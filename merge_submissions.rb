require 'csv'

output_dir = 'outputs/tutorial-1'

unseen_csv_42 = 'submission_for_unseen_seed_42.csv'
unseen_csv_46 = 'submission_for_unseen_seed_50.csv'
best_csv = 'best_submission.csv'

train_data = CSV.read('dataset/train.csv')
test_data = CSV.read('dataset/test.csv')

train_user_ids = train_data.map { |row| row[0] }.tally
test_user_ids = test_data.map { |row| row[0] }.tally

csv_42 = CSV.read(File.join(output_dir, unseen_csv_42))
csv_46 = CSV.read(File.join(output_dir, unseen_csv_46))
csv_best = CSV.read(File.join(output_dir, best_csv))

File.open('submission.csv', 'w') do |file|
  file.puts("score")

  test_data[1..].each.with_index(1) do |row, idx|
    user_id, anime_id = row

    if train_user_ids[user_id]
      file.puts(csv_best[idx].first.to_f.clamp(1.0, 10.0))
    else
      score1 = csv_best[idx].first.to_f.clamp(1.0, 10.0)
      score2 = csv_42[idx].first.to_f.clamp(1.0, 10.0)
      score3 = csv_46[idx].first.to_f.clamp(1.0, 10.0)
      score = (score1 + score2 + score3) / 3.0

      file.puts(score)
    end
  end
end
