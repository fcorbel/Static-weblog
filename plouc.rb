#!/usr/bin/env ruby
require "optparse"
require "fileutils"

VERSION = 0.1


class Plouc

	def initialize
		if getConfig
			@initialized = true
		else
			@initialized = false
		end
		@optparse = OptionParser.new {|opts|
			opts.banner = "Usage: plouc.rb [options]"

			opts.separator ""
			opts.separator "Specific options:"
			
			opts.on("-i", "--init", "Initialize a new Plouc website in the current directory") {
				puts "Initialize a new weblog"
				setupWebsite
			}
			
			opts.on("-o", "--options", "Print the current config of Plouc") {
				@config.each {|opt, value|
					puts "#{opt} = #{value}"
				}
			}
	
			opts.on("-a", "--author ARG", "Specify the author of the website (in quotes if several words) ") {|a|
				if !@initialized 
					puts "First, you need to initialize Plouc."
					exit
				end
				puts "new author: #{a}"
				@config[:author] = a
				writeConfig
			}
			
			opts.on("-c", "--create", "Create the website in the WWW directory") {
				createWebsite
			}
			
			opts.separator ""
			opts.separator "Common options:"
			
			opts.on_tail("-h", "--help", "Show this message") {
				puts @optparse.to_s
				exit
			}
	
			opts.on_tail("-v", "--version", "Show version") {
				puts "Plouc version: #{VERSION}"
				exit
			}

		}

		parseOptions(ARGV)
	end
	
	def parseOptions(args)
		@optparse.parse!(args)
	end
	
	def getConfig
		#default config
		@config = {}
		@config[:encoding] = "utf-8"
		@config[:author] = "Authorname"
		@config[:website_name] = "My weblog"
		@config[:index] = "Templates/HTML/index_default.html"
		@config[:index_CSS] = "Templates/CSS/index_default.css"
		@config[:article] = "Templates/HTML/article_default.html"
		@config[:article_CSS] = "Templates/CSS/article_default.css"
		@config[:footer] = "Templates/HTML/footer_default.html"
		@config[:header] = "Templates/HTML/header_default.html"

		#check if there is a config file and update values
		if (File.exists?("plouc.conf"))
			file = File.open("plouc.conf", "r") {|f|
				f.each {|line|
					elems = line.split('=')
					#remove \n or \r
					elems[1] = elems[1].chomp
					@config[elems[0].to_sym] = elems[1]
				}
			}
			true
		else
			false
		end
	end

	def writeConfig
		#create the configuration file
		file = File.open("plouc.conf", "w") {|f|
			@config.each {|opt, value|
				f.puts "#{opt}=#{value}"
			}
		}
	end
	
	def createIndex
		if (!File.file?("#{@config[:index]}")) 
			abort("Index template file not found: #{@config[:index]}")
		end
		puts "Create index file"
		FileUtils.cp(@config[:index_CSS], "WWW/CSS")
		index_content = File.read(@config[:index])
		index_content = processGlobalTags( index_content )
		index_content = processIndexTags( index_content )
		File.open("WWW/index.html", "w") {|file|
			file.puts index_content
		}
	end
	
	def createArticle( filename , all)
		if (!File.file?("Articles/#{filename}")) 
			abort("Article file not found: #{filename}")
		end
		new_filename = filename.chomp(".txt") + ".html"
		if (!all)
			if (File.file?("WWW/Articles/#{new_filename}"))
				if (File.mtime("WWW/Articles/#{new_filename}") > File.mtime("Articles/#{filename}"))
					puts "Skip creation of article: #{filename}"
					return
				end
			end
		end
	
		if (!File.file?("#{@config[:article]}")) 
			abort("Article template file not found: #{@config[:article]}")
		end
		puts "Create article: #{filename}"
		FileUtils.cp(@config[:article_CSS], "WWW/CSS")
		template = File.read(@config[:article])
		#copy article in template
		article = File.read("Articles/#{filename}")				
		new_article = template.gsub(/<\$article\$>/, article)
		#process global tags
		new_article = processGlobalTags( new_article )
		#process article specific tags
		new_article = processArticleTags( new_article, filename )		
		#save the new created article
		File.open("WWW/Articles/#{new_filename}", "w") {|file|
			file.puts new_article
		}
	end
	
	def processIndexTags( string_to_process )
		articles_files_list = Dir.glob("Articles/*.txt")
		articles_files_list = articles_files_list.sort_by {|filename| File.mtime(filename) }
		articles_files_list = articles_files_list.reverse
		articles_files_list.each {|filename|
			puts "#{filename}: #{File.mtime(filename)}"
		}
		#Designing the articles list
		html_code = "<ol class=\"articles_list\">\n"
		articles_files_list.each {|article|
			name = File.basename(article, ".txt")
			path = "Articles/" + name + ".html"
			date = File.mtime(article).strftime("%e %B %Y")
			html_code += "<li><a href=\"#{path}\"><h2>#{name}</h2></a><time>#{date}</time></li>\n"
		}
		html_code += "</ol>\n"
		string_to_process = string_to_process.gsub(/<\$articles_list\$>/, html_code)
		string_to_process = string_to_process.gsub(/<\$path_to_index\$>/, "index.html")
		string_to_process = string_to_process.gsub(/<\$index_CSS\$>/, "<link rel=\"stylesheet\" media=\"all\" href=\"CSS/#{File.basename(@config[:index_CSS])}\" type=\"text/css\" />")
	
	end
	
	def processArticleTags( string_to_process, article_filename )
		string_to_process = string_to_process.gsub(/<\$article_title\$>/, article_filename.chomp(".txt"))
		time = File.mtime("Articles/" + article_filename)
		#~ time = Time.now #TODO get date from the file info
		string_to_process = string_to_process.gsub(/<\$date\$>/, time.strftime("%Y-%m-%d"))
		string_to_process = string_to_process.gsub(/<\$day\$>/, time.day.to_s)
		string_to_process = string_to_process.gsub(/<\$month\$>/, time.strftime("%b"))		
		string_to_process = string_to_process.gsub(/<\$path_to_index\$>/, "../index.html")
	end
	
	def processGlobalTags( string_to_process )
		if (!File.file?("#{@config[:header]}")) 
			abort("Header template file not found: #{@config[:header]}")
		end
		footer = File.read(@config[:header])
		string_to_process = string_to_process.gsub(/<\$header\$>/, footer)

		if (!File.file?("#{@config[:footer]}")) 
			abort("Footer template file not found: #{@config[:footer]}")
		end
		footer = File.read(@config[:footer])
		string_to_process = string_to_process.gsub(/<\$footer\$>/, footer)
		
		string_to_process = string_to_process.gsub(/<\$charset\$>/, @config[:encoding])
		string_to_process = string_to_process.gsub(/<\$article_CSS\$>/, "<link rel=\"stylesheet\" media=\"all\" href=\"../CSS/#{File.basename(@config[:article_CSS])}\" type=\"text/css\" />")
		string_to_process = string_to_process.gsub(/<\$website_name\$>/, @config[:website_name])

	end
	
	def createWebsite
		#create every article page
		
		Dir.open("Articles").each {|filename|
			if filename!=".." && filename!="."
				createArticle( filename, true )
			end
		}
		
		#create the index page
		createIndex
		
	end
	
	def updateWebsite
	
	end
	
	def setupWebsite
		writeConfig
		createWebsite
		#create other stuff TODO
	end

end

if __FILE__ == $0
	pl = Plouc.new
	#~ puts "Welcome to Plouc!"

	if ARGV.empty?
		
	else
	
	
	end
end
