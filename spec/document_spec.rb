# encoding: UTF-8

require 'rails_helper'

describe Rticles::Document do

  include DocumentMacros

  describe ".from_yaml" do
    it "works with sub-paragraphs" do
      yaml = File.open('spec/fixtures/simple.yml', 'r')
      expect {
        @document = Rticles::Document.from_yaml(yaml)
      }.to change{Rticles::Paragraph.count}.by(4)
      expect(@document.outline(:with_index => true, :for_display => true)).to eq([
        '1 Paragraph 1',
        [
          '1.1 Paragraph 1.1',
          '1.2 Paragraph 1.2'
        ],
        '2 Paragraph 2'
      ])
    end

    describe "headings" do
      before(:each) do
        yaml = File.open('spec/fixtures/ips.yml', 'r')
        @document = Rticles::Document.from_yaml(yaml)
        @document.save!
      end

      it "works with headings" do
        expect(@document.top_level_paragraphs.first).to be_heading
      end

      it "works with sub-headings" do
        p = @document.top_level_paragraphs[20]
        expect(p.body).to eq "Borrowing from Members"
        expect(p.heading).to eq 2
      end
    end

    describe "topics" do
      before(:each) do
        yaml = File.open('spec/fixtures/ips.yml', 'r')
        @document = Rticles::Document.from_yaml(yaml)
        @document.save!
      end

      it "saves the topics" do
        objects_paragraph = Rticles::Paragraph.where(:topic => 'objects', :document_id => @document.id).first
        expect(objects_paragraph).to be_present
        expect(objects_paragraph.body).to eq("The objects of the Co-operative shall be to carry on the business as a co-operative and to carry on any other trade, business or service and in particular to #rticles#objectives")
      end
    end
  end

  describe "customisations" do
    before(:each) do
      yaml = File.open('spec/fixtures/constitution.yml', 'r')
      @document = Rticles::Document.from_yaml(yaml)
      @document.save!
    end

    describe "insertion" do
      it "is displayed" do
        @document.insertions = {:organisation_name => "The One Click Orgs Association"}
        expect(@document.outline(:for_display => true)[0]).to eq(
          "This is the constitution (\"Constitution\") of The One Click Orgs Association. (\"The Organisation\")"
        )
      end
    end

    describe "choice" do
      it "is displayed" do
        @document.choices = {:assets => true}
        expect(@document.outline(:for_display => true)[2]).to eq(
          "The Organisation may hold, transfer and dispose of material assets and intangible assets."
        )
      end
    end

    it "customises the entire document" do
      @document.insertions = {
        :organisation_name => "The One Click Orgs Association",
        :objectives => "developing OCO.",
        :website => "http://gov.oneclickorgs.com/",
        :voting_period => "3 days",
        :general_voting_system_description => "Supporting Votes from more than half of the Members during the Voting Period; or when more Supporting Votes than Opposing Votes have been received for the Proposal at the end of the Voting Period.",
        :constitution_voting_system_description => "Supporting Votes from more than half of the Members are received during the Voting Period; or when more Supporting Votes than Opposing Votes have been received for the Proposal at the end of the Voting Period.",
        :membership_voting_system_description => "Supporting Votes are received from more than two thirds of Members during the Voting Period."
      }
      @document.choices = {
        :assets => true
      }
      expect(@document.outline(:for_display => true)).to eq([
        "This is the constitution (\"Constitution\") of The One Click Orgs Association. (\"The Organisation\")",
        "The Organisation has the objectives of developing OCO. (\"Objectives\")",
        "The Organisation may hold, transfer and dispose of material assets and intangible assets.",
        "The Organisation uses an electronic system to carry out its governance (\"Governance System\").",
        "The Organisation has one or more members (\"Members\") who support its Objectives.",
        "Each Member nominates an email address at which they will receive important notices from the Organisation (\"Nominated Email Address\").",
        "Members may access the Governance System at the website http://gov.oneclickorgs.com/.",
        "Members may view the current Constitution on the Governance System.",
        "Members may view a register of current Members together with their Nominated Email Addresses on the Governance System.",
        "Members may resign their membership via the Governance System.",
        "Members may jointly make a decision (\"Decision\") relating to any aspect of the Organisation's activities as follows:",
        [
          "Any member may submit a proposal (\"Proposal\") on the Governance System.",
          "A Proposal may be voted on for a period of 3 days starting with its submission (\"Voting Period\").",
          "Members may view all current Proposals on the Governance System.",
          "Members may vote to support (\"Supporting Vote\") or vote to oppose (\"Opposing Vote\") a Proposal on the Governance System during the Proposal's Voting Period.",
          "Members may only vote on Proposals submitted during their membership of the Organisation.",
          "A Decision is made if a Proposal receives Supporting Votes from more than half of the Members during the Voting Period; or when more Supporting Votes than Opposing Votes have been received for the Proposal at the end of the Voting Period.",
          "except that:",
          [
            "The Constitution may only be amended by a Decision where Supporting Votes from more than half of the Members are received during the Voting Period; or when more Supporting Votes than Opposing Votes have been received for the Proposal at the end of the Voting Period."
          ],
          "and",
          [
            "New Members may be appointed (and existing Members ejected) only by a Decision where Supporting Votes are received from more than two thirds of Members during the Voting Period."
          ]
        ],
        "Members may view all Decisions on the Governance System."
      ])
    end
  end

  describe "list punctuation" do
    before(:each) do
      yaml = File.open('spec/fixtures/list_termination.yml', 'r')
      @document = Rticles::Document.from_yaml(yaml)
      @document.save!

      @document.choices = {
        users: true,
        employees: true,
        supporters: true,
      }
    end

    it "punctuates lists of sub-clauses correctly when all sub-clauses are present" do
      expect(@document.outline(for_display: true)).to eq([
        "The Board shall consist of:",
        [
          "Users;",
          "Employees;",
          "Supporters."
        ]
      ])
    end

    it "punctuates lists of sub-clauses correctly when some sub-clauses are omitted" do
      @document.choices = {
        users: true,
        employees: true,
        supporters: false
      }

      expect(@document.outline(for_display: true)).to eq([
        "The Board shall consist of:",
        [
          "Users;",
          "Employees."
        ]
      ])
    end

    it "punctuates lists correctly when generating HTML" do
      @document.choices = {
        users: true,
        employees: true,
        supporters: false
      }

      expected_html = <<-EOF
      <section>
        <ol>
          <li value="1">
            The Board shall consist of:
            <ol>
              <li value="1">Users;</li>
              <li value="2">Employees.</li>
            </ol>
          </li>
        </ol>
      </section>
      EOF

      html = @document.to_html(with_index: false)

      expect(html).to be_equivalent_to(expected_html)
    end
  end

  describe "topic lookup" do
    it "takes into account the current choices" do
      @document = Rticles::Document.create
      @document.top_level_paragraphs.create(:body => "First rule.")
      @document.top_level_paragraphs.create(:body => "#rticles#true#single_shareholding Members may only hold a single share.", :topic => 'shares')
      @document.top_level_paragraphs.create(:body => "#rticles#false#single_shareholding Members may only multiple shares.", :topic => 'shares')
      @document.top_level_paragraphs.create(:body => "#rticles#false#single_shareholding Shares may be applied for and withdrawn at any time", :topic => 'shares')
      @document.top_level_paragraphs.create(:body => "Some other rule.")
      @document.top_level_paragraphs.create(:body => "The company must keep a record of shareholdings.", :topic => 'shares')

      @document.choices[:single_shareholding] = true
      expect(@document.paragraph_numbers_for_topic('shares', true)).to eq "2, 4"

      @document.choices[:single_shareholding] = false
      expect(@document.paragraph_numbers_for_topic('shares', true)).to eq "2–3, 5"
    end

    it "works for a complex document" do
      yaml = File.open('spec/fixtures/ips.yml', 'r')
      @document = Rticles::Document.from_yaml(yaml)

      @document.choices[:single_shareholding] = true
      expect(@document.paragraph_numbers_for_topic('shares', true)).to eq "32"

      @document.choices[:single_shareholding] = false
      expect(@document.paragraph_numbers_for_topic('shares', true)).to eq "35–40"
    end

    it "can handle multiple topics" do
      @document = Rticles::Document.create
      @document.top_level_paragraphs.create(:body => "First shares rule", :topic => 'shares')
      @document.top_level_paragraphs.create(:body => "Objectives rule", :topic => 'objectives')
      @document.top_level_paragraphs.create(:body => "Other rule")
      @document.top_level_paragraphs.create(:body => "Second shares rule", :topic => 'shares')

      expect(@document.paragraph_numbers_for_topics(['shares', 'objectives'], true)).to eq '1–2, 4'
    end

  end

  describe "numbering config" do
    before(:each) do
      stub_outline([:one, [:sub_one, :sub_two, [:sub_sub_one, :sub_sub_two, :sub_sub_three], :sub_three], :two])
      @paragraph = @document.paragraphs.where(:body => :sub_sub_three).first
    end

    it "defaults to full decimal numbering" do
      expect(@paragraph.full_index).to eq "1.2.3"
    end

    it "allows customisation of the separator" do
      @document.numbering_config.separator = ' '
      expect(@paragraph.full_index(true, nil, @document.numbering_config)).to eq "1 2 3"
    end

    it "allows customisation of the list style type" do
      @document.numbering_config[1].style = Rticles::Numbering::DECIMAL
      @document.numbering_config[2].style = Rticles::Numbering::LOWER_ALPHA
      @document.numbering_config[3].style = Rticles::Numbering::LOWER_ROMAN

      expect(@paragraph.full_index(true, nil, @document.numbering_config)).to eq "1.b.iii"
    end

    it "allows customisation of the number format" do
      @document.numbering_config.separator = ' '

      @document.numbering_config[2].format = '(#)'

      expect(@paragraph.full_index(true, nil, @document.numbering_config)).to eq "1 (2) 3"
    end

    it "allows setting only the innermost number should be printed" do
      @document.numbering_config.innermost_only = true
      expect(@paragraph.full_index(true, nil, @document.numbering_config)).to eq "3"
    end
  end

end
