require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

response = civic_info.representative_info_by_address(address: 80_202,
                                                     levels: 'country',
                                                     roles: %w[legislatorUpperBody legislatorLowerBody])

officials = response.officials

def clean_zipcode(zip)
  zip = zip.to_s
  zip.rjust(5, '0').slice(0, 5)
end

def legislator_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    )
    legislators.officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') { |file| file.puts form_letter }
end

def valid_number(phone)
  standard_number = %r{^(\(\d{3}\)|\d{3})[) \-./]?\d{3}[ \-./]?\d{4}$}

  phone.gsub!(/[^0-9]/, '')

  if phone.match(standard_number)
    phone
  elsif phone.match(/1.{10}/)
    phone[1..]
  else
    'Bad Number'
  end
end

puts 'EventManager initialized.'
puts 'Going through the csv...'
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
contents = CSV.open('event_attendees_large.csv', headers: true, header_converters: :symbol)

reg_hour = Hash.new(0)
reg_days = Hash.new(0)

contents.each do |row|
  id = row[0]

  name = row[:first_name]

  zip = clean_zipcode(row[:zipcode])

  phone = valid_number(row[:homephone])

  registered = DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M')

  day = registered.strftime('%A')

  hour = registered.strftime('%H')

  reg_hour[hour] += 1

  reg_days[day] += 1

  legislators = legislator_by_zipcode(zip)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

most_common_hour = reg_hour.key(reg_hour.values.max)
most_common_day = reg_days.key(reg_days.values.max)
puts "Most common hour is: #{most_common_hour}"
puts "Most common day is: #{most_common_day}"
