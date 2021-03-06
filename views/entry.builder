xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.entry(:xmlns => 'http://www.w3.org/2005/Atom') do
  xml.id           @entry.url
  xml.title        @entry.title
  xml.content      @entry.content, :type => 'html'
  xml.updated      @entry.updated
  xml.published    @entry.published
  xml.tag! 'atomos:markdown', @entry.markdown, 'xmlns:atomos' => 'http://daringfireball.net/projects/markdown/'
  xml.link :rel => "edit",      :href => @entry.edit_url
  xml.link :rel => "alternate", :href => @entry.url
  @entry.tags.each do |tag|
    xml.category :term => tag
  end
end
