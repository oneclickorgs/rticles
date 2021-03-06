require 'rails_helper'

describe Rticles::Paragraph do
  include DocumentMacros

  describe "top-level positioning" do
    before(:each) do
      @document = Rticles::Document.create
    end

    it "is assigned correctly when pushing paragraphs to a document" do
      paragraphs = Array.new(4){Rticles::Paragraph.new}
      paragraphs.each{|p| @document.top_level_paragraphs.push(p)}
      @document.save
      @document.reload
      expect(@document.top_level_paragraphs.map(&:position)).to eq([1, 2, 3, 4])
    end
  end

  describe "child paragraphs" do
    before(:each) do
      @document = Rticles::Document.create
      @paragraph = @document.top_level_paragraphs.create
    end

    it "are assigned parentage when pushing child paragraphs to a parent paragraph" do
      child = Rticles::Paragraph.new
      @paragraph.children.push(child)
      child.reload
      expect(child.parent_id).to eq(@paragraph.id)
    end

    it "are associated with their parent's document" do
      child = Rticles::Paragraph.new
      @paragraph.children.push(child)
      child.reload
      expect(child.document_id).to eq(@document.id)
    end
  end

  describe "inserting paragraphs" do
    before(:each) do
      @document = Rticles::Document.create
      3.times{|i| @document.top_level_paragraphs.create(:body => "Originally #{i + 1}")}
    end

    it "inserts a paragraph at the top" do
      paragraph = @document.paragraphs.build(:body => "New", :before_id => @document.top_level_paragraphs.first.id)
      paragraph.save!
      @document.reload
      expect(@document.top_level_paragraphs.map{|p| [p.parent_id, p.position, p.body]}).to eq([
        [nil, 1, "New"],
        [nil, 2, "Originally 1"],
        [nil, 3, "Originally 2"],
        [nil, 4, "Originally 3"]
      ])
    end

    it "inserts a paragraph at the bottom" do
      paragraph = @document.paragraphs.build(:body => "New", :after_id => @document.top_level_paragraphs.last.id)
      paragraph.save!
      @document.reload
      expect(@document.top_level_paragraphs.map{|p| [p.parent_id, p.position, p.body]}).to eq([
        [nil, 1, "Originally 1"],
        [nil, 2, "Originally 2"],
        [nil, 3, "Originally 3"],
        [nil, 4, "New"]
      ])
    end

    it "inserts a paragraph in the middle" do
      paragraph = @document.paragraphs.build(:body => "New", :before_id => @document.top_level_paragraphs[1].id)
      paragraph.save!
      @document.reload
      expect(@document.top_level_paragraphs.map{|p| [p.parent_id, p.position, p.body]}).to eq([
        [nil, 1, "Originally 1"],
        [nil, 2, "New"],
        [nil, 3, "Originally 2"],
        [nil, 4, "Originally 3"]
      ])
    end

    context "into a list of children" do
      before(:each) do
        @first_top_paragraph = @document.top_level_paragraphs.first
        3.times{|i| @document.paragraphs.create(:parent_id => @first_top_paragraph.id, :body => "Child originally #{i + 1}")}
      end

      it "inserts a paragraph at the top" do
        paragraph = @document.paragraphs.build(:body => "New", :before_id => @first_top_paragraph.children.first.id)
        paragraph.save!
        @first_top_paragraph.reload
        expect(@first_top_paragraph.children.map{|p| [p.parent_id, p.position, p.body]}).to eq([
          [@first_top_paragraph.id, 1, "New"],
          [@first_top_paragraph.id, 2, "Child originally 1"],
          [@first_top_paragraph.id, 3, "Child originally 2"],
          [@first_top_paragraph.id, 4, "Child originally 3"]
        ])
      end

      it "inserts a paragraph at the bottom" do
        paragraph = @document.paragraphs.build(:body => "New", :after_id => @first_top_paragraph.children.last.id)
        paragraph.save!
        @first_top_paragraph.reload
        expect(@first_top_paragraph.children.map{|p| [p.parent_id, p.position, p.body]}).to eq([
          [@first_top_paragraph.id, 1, "Child originally 1"],
          [@first_top_paragraph.id, 2, "Child originally 2"],
          [@first_top_paragraph.id, 3, "Child originally 3"],
          [@first_top_paragraph.id, 4, "New"]
        ])
      end

      it "inserts a paragraph in the middle" do
        paragraph = @document.paragraphs.build(:body => "New", :before_id => @first_top_paragraph.children[1].id)
        paragraph.save!
        @first_top_paragraph.reload
        expect(@first_top_paragraph.children.map{|p| [p.parent_id, p.position, p.body]}).to eq([
          [@first_top_paragraph.id, 1, "Child originally 1"],
          [@first_top_paragraph.id, 2, "New"],
          [@first_top_paragraph.id, 3, "Child originally 2"],
          [@first_top_paragraph.id, 4, "Child originally 3"]
        ])
      end
    end
  end

  describe "deleting" do
    it "deletes its children" do
      @document = Rticles::Document.create
      @tlp = @document.top_level_paragraphs.create(:body => "top-level")
      3.times{@document.paragraphs.create(:parent_id => @tlp.id)}
      expect(@document.paragraphs.map{|p| [p.parent_id, p.position]}).to eq [
        [nil, 1],
        [@tlp.id, 1],
        [@tlp.id, 2],
        [@tlp.id, 3]
      ]

      expect(@document.paragraphs.count).to eq 4
      @document.reload.top_level_paragraphs.first.destroy
      expect(@document.reload.paragraphs.count).to eq(0)
    end
  end

  describe "indenting" do
    it "makes the paragraph a child of its previous sibling" do
      stub_outline([:one, :two])
      @document.top_level_paragraphs[1].indent!
      expect(@document.reload.outline).to eq(['one', ['two']])
    end

    it "goes at the bottom of the previous sibling's children" do
      stub_outline([:one, [:sub_one, :sub_two], :two])
      @document.top_level_paragraphs[1].indent!
      expect(@document.reload.outline).to eq(['one', ['sub_one', 'sub_two', 'two']])
    end
  end

  describe "outdenting" do
    it "inserts itself back into its parent's level" do
      stub_outline([:one, [:two]])
      @document.top_level_paragraphs[0].children[0].outdent!
      expect(@document.reload.outline).to eq(['one', 'two'])
    end

    it "splits its siblings" do
      stub_outline [:one, [:sub_one, :sub_two, :sub_three], :two]
      @document.top_level_paragraphs[0].children[1].outdent!
      expect(@document.reload.outline).to eq(['one', ['sub_one'], 'sub_two', ['sub_three'], 'two'])
    end
  end

  describe "index" do
    before(:each) do
      @document = Rticles::Document.create
      @document.top_level_paragraphs.create(:body => 'one')
      @document.top_level_paragraphs.create(:body => 'Heading one', :heading => 1)
      @document.top_level_paragraphs.create(:body => 'two')
      @document.top_level_paragraphs.create(:body => '#rticles#false#choice Optional paragraph')
      @document.top_level_paragraphs.create(:body => 'three')

      @document.choices[:choice] = true
    end

    it "ignores headings" do
      expect(@document.paragraphs[0].index).to eq 1
      expect(@document.paragraphs[2].index).to eq 2
    end

    it "returns nil for headings" do
      expect(@document.paragraphs[1].index).to be_nil
    end

    it "ignores paragraphs omitted by choices" do
      expect(@document.paragraphs[4].index(@document.choices)).to eq 3
    end
  end

  describe "generating HTML" do
    before(:each) do
      @document = Rticles::Document.create
      @document.top_level_paragraphs.create(:body => "A Simple Constitution", :heading => 1)
      @document.top_level_paragraphs.create(:body => "For demonstration purposes only", :heading => 2, :continuation => true)

      @document.top_level_paragraphs.create(:body => "This is the first rule.")

      p = @document.top_level_paragraphs.create(:body => "This is the second rule, which applies when:")
      @document.paragraphs.create(:body => "This condition;", :parent_id => p.id)
      @document.paragraphs.create(:body => "and this condition.", :parent_id => p.id)
      @document.top_level_paragraphs.create(:body => "except when it is a Full Moon.", :continuation => true)

      @document.top_level_paragraphs.create(:body => "This is the third rule.")

      @document.top_level_paragraphs.create(:body => "This is the fourth rule.")
      @document.top_level_paragraphs.create(:body => "And finally...", :heading => 2)
      @document.top_level_paragraphs.create(:body => "This is the final rule.")
    end

    it "works" do
      expected_html = <<-EOF
      <section>
        <hgroup>
          <h1>A Simple Constitution</h1>
          <h2>For demonstration purposes only</h2>
        </hgroup>
        <ol>
          <li value="1">1 This is the first rule.</li>
          <li value="2">
            2 This is the second rule, which applies when:
            <ol>
              <li value="1">2.1 This condition;</li>
              <li value="2">2.2 and this condition.</li>
            </ol>
            except when it is a Full Moon.
          </li>
          <li value="3">3 This is the third rule.</li>
          <li value="4">4 This is the fourth rule.</li>
        </ol>
        <h2>And finally...</h2>
        <ol>
          <li value="5">5 This is the final rule.</li>
        </ol>
      </section>
      EOF

      html = @document.to_html

      expect(html).to be_equivalent_to(expected_html)
    end

    context "with insertions" do
      it "converts newlines into br tags" do
        @document.top_level_paragraphs.create(
          :body => "A custom rule is: #rticles#custom_rule",
          :after_id => @document.top_level_paragraphs.all[4].id
        )

        expected_html = <<-EOF
        <section>
          <hgroup>
            <h1>A Simple Constitution</h1>
            <h2>For demonstration purposes only</h2>
          </hgroup>
          <ol>
            <li value="1">1 This is the first rule.</li>
            <li value="2">
              2 This is the second rule, which applies when:
              <ol>
                <li value="1">2.1 This condition;</li>
                <li value="2">2.2 and this condition.</li>
              </ol>
              except when it is a Full Moon.
            </li>
            <li value="3">3 A custom rule is: I can format my clauses<br>how I<br>please.</li>
            <li value="4">4 This is the third rule.</li>
            <li value="5">5 This is the fourth rule.</li>
          </ol>
          <h2>And finally...</h2>
          <ol>
            <li value="6">6 This is the final rule.</li>
          </ol>
        </section>
        EOF

        @document.insertions = {:custom_rule => "I can format my clauses\nhow I\nplease."}

        html = @document.to_html

        expect(html).to be_equivalent_to(expected_html)
      end
    end

    context "with choices" do
      before(:each) do
        @document.top_level_paragraphs.create(
          :body => "#rticles#true#free_cake All members shall be entitled to free cake",
          :after_id => @document.top_level_paragraphs.all[4].id
        )
      end

      it "includes the 'true' clause when the choice is set to true" do
        expected_html = <<-EOF
        <section>
          <hgroup>
            <h1>A Simple Constitution</h1>
            <h2>For demonstration purposes only</h2>
          </hgroup>
          <ol>
            <li value="1">1 This is the first rule.</li>
            <li value="2">
              2 This is the second rule, which applies when:
              <ol>
                <li value="1">2.1 This condition;</li>
                <li value="2">2.2 and this condition.</li>
              </ol>
              except when it is a Full Moon.
            </li>
            <li value="3">3 All members shall be entitled to free cake</li>
            <li value="4">4 This is the third rule.</li>
            <li value="5">5 This is the fourth rule.</li>
          </ol>
          <h2>And finally...</h2>
          <ol>
            <li value="6">6 This is the final rule.</li>
          </ol>
        </section>
        EOF

        @document.choices = {:free_cake => true}

        html = @document.to_html

        expect(html).to be_equivalent_to(expected_html)
      end

      it "excludes the 'true' clause when the choice is set to false" do
        expected_html = <<-EOF
        <section>
          <hgroup>
            <h1>A Simple Constitution</h1>
            <h2>For demonstration purposes only</h2>
          </hgroup>
          <ol>
            <li value="1">1 This is the first rule.</li>
            <li value="2">
              2 This is the second rule, which applies when:
              <ol>
                <li value="1">2.1 This condition;</li>
                <li value="2">2.2 and this condition.</li>
              </ol>
              except when it is a Full Moon.
            </li>
            <li value="3">3 This is the third rule.</li>
            <li value="4">4 This is the fourth rule.</li>
          </ol>
          <h2>And finally...</h2>
          <ol>
            <li value="5">5 This is the final rule.</li>
          </ol>
        </section>
        EOF

        @document.choices = {:free_cake => false}

        html = @document.to_html

        expect(html).to be_equivalent_to(expected_html)
      end

      context "when the choices cause an entire paragraph group to be omitted" do
        before(:each) do
          parent = @document.top_level_paragraphs.create(
            :body => "The following optional rules will apply",
            :after_id => @document.top_level_paragraphs.all[5].id
          )
          @document.paragraphs.create(
            :body => '#rticles#true#option_one Option one',
            :parent_id => parent.id
          )
          @document.paragraphs.create(
            :body => '#rticles#true#option_two Option two',
            :parent_id => parent.id
          )
          @document.choices = {option_one: false, option_two: false}
        end

        it "does not raise an error" do
          expect{@document.to_html}.to_not raise_error
        end
      end
    end

    context "without indexes" do
      it "works" do
        expected_html = <<-EOF
        <section>
          <hgroup>
            <h1>A Simple Constitution</h1>
            <h2>For demonstration purposes only</h2>
          </hgroup>
          <ol>
            <li value="1">This is the first rule.</li>
            <li value="2">
              This is the second rule, which applies when:
              <ol>
                <li value="1">This condition;</li>
                <li value="2">and this condition.</li>
              </ol>
              except when it is a Full Moon.
            </li>
            <li value="3">This is the third rule.</li>
            <li value="4">This is the fourth rule.</li>
          </ol>
          <h2>And finally...</h2>
          <ol>
            <li value="5">This is the final rule.</li>
          </ol>
        </section>
        EOF

        html = @document.to_html(:with_index => false)

        expect(html).to be_equivalent_to(expected_html)
      end
    end
  end
end
