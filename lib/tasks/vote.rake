researcher_info = [
  {
    name: 'Peter Bailis',
    weight: 100,
  },
  {
    name: 'Nancy Lynch',
    weight: 75,
  },
  {
    name: 'Barbara Liskov',
    weight: 60,
  },
  {
    name: 'Leslie Lamport',
    weight: 45,
  },
  {
    name: 'Michael Fisher',
    weight: 30,
  },
  {
    name: 'Michael Paterson',
    weight: 53,
  },
  {
    name: 'Justin Bieber',
    weight: 1,
  },
]

researcher_names   = researcher_info.map{|info| info[:name]}
researcher_weights = researcher_info.map{|info| info[:weight]}

namespace :vote do
  task :init, [:num_researchers] => :environment do |tt, args|
    num_researchers = Integer(args[:num_researchers] || researcher_names.count)

    ActiveRecord::Base.connection.execute('delete from vote_tallies')
    ActiveRecord::Base.connection.execute('delete from vote_records')

    researcher_names.take(num_researchers).each do |name|
      VoteTally.create!(name: name, num_votes: 0)
    end
  end
end

namespace :vote do
  task :tally, [:num_researchers, :num_votes_per_thread, :num_threads] => :environment do |tt, args|
    num_researchers      = Integer(args[:num_researchers] || researcher_names.count)
    num_votes_per_thread = Integer(args[:num_votes_per_thread] || 1)
    num_threads          = Integer(args[:num_threads] || 1)

    total_weight          = Float(researcher_weights.take(num_researchers).inject(&:+))
    researcher_thresholds = researcher_weights.take(num_researchers).inject([]) { |result,current|
      result + [(result.last || 0) + current/total_weight]
    }

    output_mutex = Mutex.new

    ActiveRecord::Base.clear_active_connections!
    VoteTally

    wait_for_it = true

    threads = num_threads.times.map do |thread_idx|
      Thread.new do
        while wait_for_it
        end

        num_votes_per_thread.times.each do |vote_idx|
          ActiveRecord::Base.connection_pool.with_connection do
            rand_val = Kernel.rand
            researcher_idx = researcher_thresholds.select{|thresh| thresh < rand_val}.count
            researcher_name = researcher_names[researcher_idx]

            VoteTally.transaction(isolation: :read_committed) do
              tally = VoteTally.find_by_sql(['select * from vote_tallies where name = ? for update', researcher_name]).first
              tally.num_votes += 1
              tally.save!
            end

            # output_mutex.synchronize {
            #   puts "#{Time.now.utc.iso8601(6)} thread #{Thread.current.object_id} vote #{vote_idx} #{researcher_name}"
            # }

          end
        end
      end
    end

    wait_for_it = false

    start = Time.now
    threads.each{|thread| thread.join}
    elapsed = Time.now - start

    total_votes   = num_threads*num_votes_per_thread
    votes_per_sec = total_votes/elapsed
    puts "elapsed = #{'%1.3e' % elapsed} total_votes = #{total_votes} votes_per_sec = #{'%1.3e' % (votes_per_sec)}"
  end
end

namespace :vote do
  task :record, [:num_researchers, :num_votes_per_thread, :num_threads] => :environment do |tt, args|
    num_researchers      = Integer(args[:num_researchers] || researcher_names.count)
    num_votes_per_thread = Integer(args[:num_votes_per_thread] || 1)
    num_threads          = Integer(args[:num_threads] || 1)

    total_weight          = Float(researcher_weights.take(num_researchers).inject(&:+))
    researcher_thresholds = researcher_weights.take(num_researchers).inject([]) { |result,current|
      result + [(result.last || 0) + current/total_weight]
    }

    output_mutex = Mutex.new

    ActiveRecord::Base.clear_active_connections!
    VoteRecord

    wait_for_it = true

    threads = num_threads.times.map do |thread_idx|
      Thread.new do
        while wait_for_it
        end

        num_votes_per_thread.times.each do |vote_idx|
          ActiveRecord::Base.connection_pool.with_connection do
            rand_val = Kernel.rand
            researcher_idx = researcher_thresholds.select{|thresh| thresh < rand_val}.count
            researcher_name = researcher_names[researcher_idx]

            VoteRecord.transaction(isolation: :read_committed) do
              VoteRecord.create!(
                uuid: SecureRandom.uuid.to_s,
                name: researcher_name,
                has_been_counted: false,
              )
            end

            # output_mutex.synchronize {
            #   puts "#{Time.now.utc.iso8601(6)} thread #{Thread.current.object_id} vote #{vote_idx} #{researcher_name}"
            # }

          end
        end
      end
    end

    wait_for_it = false

    start = Time.now
    threads.each{|thread| thread.join}
    elapsed = Time.now - start

    total_votes   = num_threads*num_votes_per_thread
    votes_per_sec = total_votes/elapsed
    puts "elapsed = #{'%1.3e' % elapsed} total_votes = #{total_votes} votes_per_sec = #{'%1.3e' % (votes_per_sec)}"
  end
end
