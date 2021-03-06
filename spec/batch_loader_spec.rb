require "spec_helper"

RSpec.describe BatchLoader do
  describe '.sync!' do
    it "syncs all BatchLoaders" do
      user1 = User.save(id: 1)
      post1 = Post.new(user_id: user1.id)
      user2 = User.save(id: 2)
      post2 = Post.new(user_id: user2.id)
      result = {user1: post1.user_lazy, user2: post2.user_lazy}

      expect(User).to receive(:where).with(id: [1, 2]).once.and_call_original

      BatchLoader.sync!(result)

      expect(result).to eq(user1: user1, user2: user2)
    end
  end

  describe '#sync' do
    it 'raises an error if batch was not provided' do
      expect {
        BatchLoader.for(1).sync
      }.to raise_error(BatchLoader::NoBatchError, "Please provide a batch block first")
    end

    it 'caches the result even between different BatchLoader instances' do
      user = User.save(id: 1)
      post = Post.new(user_id: user.id)

      expect(User).to receive(:where).with(id: [1]).once.and_call_original

      expect(post.user_lazy.sync).to eq(user)
      expect(post.user_lazy.sync).to eq(user)
    end

    it 'caches the result for the same BatchLoader instance' do
      user = User.save(id: 1)
      post = Post.new(user_id: user.id)
      user_lazy = post.user_lazy

      expect(User).to receive(:where).with(id: [1]).once.and_call_original

      expect(user_lazy.sync).to eq(user)
      expect(user_lazy.sync).to eq(user)
    end
  end

  describe '#load' do
    it 'loads the data even in a separate thread' do
      lazy = BatchLoader.for(1).batch do |nums, batch_loader|
        nums.each do |num|
          thread = Thread.new { batch_loader.load(num, num + 1) }
          thread.join
        end
      end

      expect(lazy.sync).to eq(2)
    end
  end

  describe '#batch' do
    it 'raises an exception if batch was called twice' do
      post = Post.new(user_id: 1)

      expect {
        post.user_lazy.batch { nil }
      }.to raise_error(BatchLoader::BatchAlreadyExistsError)
    end

    it 'works without cache between different BatchLoader instances for the same item' do
      user1 = User.save(id: 1)
      user2 = User.save(id: 2)
      post = Post.new(user_id: user1.id)

      expect(User).to receive(:where).with(id: [1]).once.and_call_original
      expect(post.user_lazy.sync).to eq(user1)

      post.user_id = user2.id

      expect(User).to receive(:where).with(id: [2]).once.and_call_original
      expect(post.user_lazy(cache: false).sync).to eq(user2)
    end

    it 'works without cache for the same BatchLoader instance' do
      user = User.save(id: 1)
      post = Post.new(user_id: user.id)
      user_lazy = post.user_lazy(cache: false)

      expect(User).to receive(:where).with(id: [1]).twice.and_call_original

      expect(user_lazy.sync).to eq(user)
      expect(user_lazy.sync).to eq(user)
    end
  end
end
