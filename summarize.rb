require 'csv'
require 'amakanize'
require "damerau-levenshtein"

class UnionFind
  def initialize(n)
    @size = Array.new(n, 1)
    @rank = Array.new(n, 0)
    @parent = []

    (0..n).each do |i|
      @parent[i] = i
    end
  end

  def find(x)
    if @parent[x] == x
      x
    else
      @parent[x] = find(@parent[x])
    end
  end

  def unite(x, y)
    x = find(x)
    y = find(y)
    return if x == y

    if @rank[x] < @rank[y]
      @parent[x] = y
      @size[y] += @size[x]
    else
      @parent[y] = x
      @size[x] += @size[y]

      @rank[x] += 1 if @rank[x] == @rank[y]
    end
  end

  def same?(x, y)
    find(x) == find(y)
  end

  def size(x)
    @size[find(x)]
  end
end


anime_csv = CSV.read('dataset/anime.csv')
rows = anime_csv[1..].map(&:dup)
  .map { |row| row << row[2].gsub(/劇場版/, '').strip; row }
  .map { |row| row[-1] = Amakanize::SeriesName.new(row.last).to_s.split.first; row }
  .map.with_index(1) { |row, idx| [idx, row].flatten }
L = rows.size
uf = UnionFind.new(10000)
series_name = Hash.new

0.upto(L - 1) do |i|
  name1 = rows[i].last

  (i + 1).upto(L - 1) do |j|
    name2 = rows[j].last
    dist = DamerauLevenshtein.distance(name1, name2)

    if dist <= 1
      uf.unite(i, j)
    end
  end
end

0.upto(L - 1) do |i|
  parent = uf.find(i)
  name = rows[i].last
  series_name[parent] = name
end

File.open('dataset/anime_with_name.csv', 'w') do |file|
  header = anime_csv[0]
  header.insert(3, 'series_name')
  file.puts(header.to_csv)

  anime_csv[1..].each_with_index do |row, idx|
    parent = uf.find(idx)
    name = series_name[parent]
    row.insert(3, name)

    file.puts(row.to_csv)
  end
end
