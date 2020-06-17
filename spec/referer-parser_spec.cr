require "./spec_helper"

describe RefererParser::Parser do
  describe "with the default parser" do
    it "should have a non-empty domain_index" do
      parser = RefererParser::Parser.new
      parser.domain_index.should_not be_empty
    end

    it "should have a non-empty name_hash" do
      parser = RefererParser::Parser.new
      parser.name_hash.should_not be_empty
    end

    it "should have a non-empty name_hash" do
      parser = RefererParser::Parser.new(RefererParser::Parser::DefaultFile, false)
      parser.name_hash.should be_empty
      parser.domain_index.should be_empty
    end

    it "should be clearable" do
      parser = RefererParser::Parser.new
      parser.name_hash.should_not be_empty
      parser.clear!
      parser.name_hash.should be_empty
      parser.domain_index.should be_empty
    end
  end

  describe "general behavior" do
    it "should return the better result when the referer contains two or more parameters" do
      parser = RefererParser::Parser.new
      parsed = parser.parse("http://search.tiscali.it/?tiscalitype=web&collection=web&q=&key=hello")
      parsed[:term].should eq("hello")
    end

    it "should return the better result when the referer contains same parameters" do
      parser = RefererParser::Parser.new
      parsed = parser.parse("http://search.tiscali.it/?tiscalitype=web&collection=web&key=&key=hello")
      parsed[:term].should eq("hello")
    end

    it "should return the normalized domain" do
      parser = RefererParser::Parser.new
      parsed = parser.parse("http://it.images.search.YAHOO.COM/images/view;_ylt=A0PDodgQmGBQpn4AWQgdDQx.;_ylu=X3oDMTBlMTQ4cGxyBHNlYwNzcgRzbGsDaW1n?back=http%3A%2F%2Fit.images.search.yahoo.com%2Fsearch%2Fimages%3Fp%3DEarth%2BMagic%2BOracle%2BCards%26fr%3Dmcafee%26fr2%3Dpiv-web%26tab%3Dorganic%26ri%3D5&w=1064&h=1551&imgurl=mdm.pbzstatic.com%2Foracles%2Fearth-magic-oracle-cards%2Fcard-1.png&rurl=http%3A%2F%2Fwww.psychicbazaar.com%2Foracles%2F143-earth-magic-oracle-cards.html&size=2.8+KB&name=Earth+Magic+Oracle+Cards+-+Psychic+Bazaar&p=Earth+Magic+Oracle+Cards&oid=f0a5ad5c4211efe1c07515f56cf5a78e&fr2=piv-web&fr=mcafee&tt=Earth%2BMagic%2BOracle%2BCards%2B-%2BPsychic%2BBazaar&b=0&ni=90&no=5&ts=&tab=organic&sigr=126n355ib&sigb=13hbudmkc&sigi=11ta8f0gd&.crumb=IZBOU1c0UHU")
      parsed[:domain].should eq("images.search.yahoo.com")
      parsed[:source].should eq("Yahoo! Images")
    end

    it "reddit checks" do
      parser = RefererParser::Parser.new
      parsed = parser.parse("http://old.reddit.com")
      parsed2 = parser.parse("http://reddit.com")
      parsed[:domain].should eq("old.reddit.com")
      parsed[:source].should eq("Reddit")
      parsed2[:domain].should eq("reddit.com")
      parsed2[:source].should eq("Reddit")
    end
  end

  describe "optimize_index" do
    it "should have out of order and duplicate domains before optimization" do
      parser = RefererParser::Parser.new(RefererParser::Parser::DefaultFile, false)
      domains = ["fnord.com", "fnord.com", "fnord.com/path"]
      parser.add_referer("internal", "Fnord", domains)
      parser.domain_index["fnord.com"].transpose.first.should eq(["/", "/", "/path"])
    end

    it "should have out of order domains before optimization" do
      parser = RefererParser::Parser.new(RefererParser::Parser::DefaultFile, false)
      domains = ["fnord.com", "fnord.com", "fnord.com/path"]
      parser.add_referer("internal", "Fnord", domains)
      parser.optimize_index!
      parser.domain_index["fnord.com"].transpose.first.should eq(["/path", "/"])
    end
  end

  describe "add_referer" do
    it "should add a referer to the domain_index" do
      parser = RefererParser::Parser.new(RefererParser::Parser::DefaultFile, false)
      parser.domain_index.size.should eq(0)
      parser.add_referer("internal", "Fnord", ["fnord.com"])
      parser.domain_index.size.should eq(1)
      parser.domain_index.keys.first.should eq("fnord.com")
    end

    it "should add a referer with multiple domains to the domain_index" do
      parser = RefererParser::Parser.new(RefererParser::Parser::DefaultFile, false)
      parser.domain_index.size.should eq(0)
      parser.add_referer("internal", "Fnord", ["fnord.com", "boo.com"])
      parser.domain_index.size.should eq(2)
      parser.domain_index.keys.first.should eq("fnord.com")
      parser.domain_index.keys[1].should eq("boo.com")
    end

    it "should add a referer to the name_hash" do
      parser = RefererParser::Parser.new(RefererParser::Parser::DefaultFile, false)
      parser.name_hash.keys.size.should eq(0)
      parser.add_referer("internal", "Fnord", ["fnord.com"])
      parser.name_hash.keys.size.should eq(1)
      parser.name_hash.first.first.should eq("Fnord-internal")
    end
  end
end
