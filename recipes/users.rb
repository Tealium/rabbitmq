#
# Cookbook Name:: rabbitmq
# Recipe:: users
#
# Copyright 2012, Gautam Dey
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#include_recipe "rabbitmq::default"

Chef::Log.info("Running Rabbitmq::Users");
require 'pp'

# We need to find the current set of users.

# Need a better way then using ``.
current_users = `rabbitmqctl list_users | head -n -1 | tail -n +2 | cut -f 1`.split("\n")
Chef::Log.info("Found current users: #{current_users.join(' , ')}");
users_to_delete = (current_users + ["guest"]).uniq

app_environment = node["app_environment"] || "development"



Chef::Log.info("Looking for environment: #{app_environment}");
rabbitmq_db = search(:rabbitmq_users,"id:#{app_environment}").first
rabbitmq_users = rabbitmq_db["users"].keys

Chef::Log.info("Found rabbit users: #{rabbitmq_users.count}");

rabbitmq_users.each do |username|

   Chef::Log.info("Adding user: #{username}")
   user = rabbitmq_db["users"][username]
   # We do not want to delete this user.
   users_to_delete.delete(username)

   # Now let's add the user.
   rabbitmq_user username do
     password user["password"]
     action :add
   end

   if user["tags"].nil? 
      
      Chef::Log.info("Clearing tags for user #{username}")

      rabbitmq_user username do
         action :clear_tags
      end

   else

      Chef::Log.info("Adding tags[ #{user["tags"].join(",")} ] for user #{username}")

      rabbitmq_user username do 
         tags user["tags"]
         action :set_tags
      end
   
   end

   # Let's see if we need to create the vhost.
   unless user["vhosts"].nil?
      user["vhosts"].each do |user_vhost, user_permissions|
         rabbitmq_vhost user_vhost do
           Chef::Log.info("Adding VHost: #{user_vhost}")
           action :add
         end

         Chef::Log.info("Add #{username} to #{user_vhost} with permissions #{user_permissions}")
         rabbitmq_user username do
            vhost user_vhost
            permissions user_permissions
            action :set_permissions
         end
      end
   end

   # Now we need to delete any users that were not in our databag.
   if node[:rabbitmq][:delete_users] 
      Chef::Log.info("Removing extra users.");
      users_to_delete.each do |user|
         
         Chef::Log.info("Removing user: #{user}")
         rabbitmq_user user do
           action :delete
         end
      end
   end

end


