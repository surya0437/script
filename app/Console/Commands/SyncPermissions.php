<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class SyncPermissions extends Command
{
    protected $signature = 'sync:permissions';

    protected $description = 'Assign all permissions to a role and model';

    public function handle()
    {
        $modelId = $this->ask('Enter Model ID') ?? 247;
        $roleId  = $this->ask('Enter Role ID') ?? 1;

        $permissions = DB::table('permissions')
            ->where('name', 'not like', '%own-%')
            ->select('id', 'name')
            ->get();

        if ($permissions->isEmpty()) {
            $this->error('No permissions found!');
            return;
        }

        DB::beginTransaction();

        try {

            $roleCount = $this->syncRolePermissions($permissions, $roleId);

            $modelCount = $this->syncModelPermissions($permissions, $modelId);

            DB::commit();

            $this->info("Role permissions synced: {$roleCount}");
            $this->info("Model permissions synced: {$modelCount}");
            $this->info('Permissions synced successfully!');
        } catch (\Exception $e) {

            DB::rollBack();

            $this->error('Error: ' . $e->getMessage());
        }
    }

    private function syncRolePermissions($permissions, $roleId)
    {
        $count = 0;

        foreach ($permissions as $permission) {

            $this->info("Syncing {$permission->name} for role");

            DB::table('role_has_permissions')
                ->updateOrInsert([
                    'permission_id' => $permission->id,
                    'role_id'       => $roleId,
                ]);

            $count++;
        }

        return $count;
    }

    private function syncModelPermissions($permissions, $modelId)
    {
        $count = 0;

        foreach ($permissions as $permission) {

            $this->info("Syncing {$permission->name} for model");

            DB::table('model_has_permissions')
                ->updateOrInsert([
                    'permission_id' => $permission->id,
                    'model_id'      => $modelId,
                    'model_type'    => 'App\Models\Admin',
                ]);

            $count++;
        }

        return $count;
    }
}
