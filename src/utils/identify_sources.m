function sources = identify_sources(varargin)
    %
    % finds the most likely files in the detrivatives that was used to create
    % this file
    %
    % USAGE::
    %
    %   sources = identify_sources(derivatives, map, verbose)
    %
    % :param file: SPM preprocessed filename (can be fullpath);
    %              for example ``wmsub-01_ses-01_T1w.nii``
    % :type file: string
    %
    %
    % (C) Copyright 2021 spm_2_bids developers

    % "r" could mean realigned or resliced...
    %     'sr'
    %     'sra'
    %     'wr'
    %     'wra'
    % those will throw warnings

    % TODO
    % functional to anatomical coregistration
    % anatomical to functional coregistration

    default_map = Mapping();
    default_map = default_map.default();

    sources = '';

    prefix_based = true;

    add_deformation_field = false;
    deformation_field = 'TODO: add deformation field';

    % TODO? grab all the anat suffixes from BIDS schema?
    covered_suffixes = {'T1w', ...
                        'T2w', ...
                        'PDw', ...
                        'T2starw', ...
                        'inplaneT1', ...
                        'inplaneT2', ...
                        'PD', ...
                        'PDT2', ...
                        'T2star', ...
                        'FLASH', ...
                        'T1map', ...
                        'T2map', ...
                        'T2starmap', ...
                        'R1map', ...
                        'R2map', ...
                        'R2starmap', ...
                        'PDmap', ...
                        'UNIT1'};

    args = inputParser;

    addOptional(args, 'derivatives', pwd, @ischar);
    addOptional(args, 'map', default_map);
    addOptional(args, 'verbose', true, @islogical);

    parse(args, varargin{:});

    derivatives = args.Results.derivatives;
    map = args.Results.map;
    verbose = args.Results.verbose;

    if isempty(derivatives)
        return
    end

    if endsWith(derivatives, '_seg8.mat')

        prefix_based = false;

        derivatives = strrep(derivatives, '_seg8.mat', '.nii');

    elseif endsWith(derivatives, '_uw.mat')

        prefix_based = false;

        derivatives = strrep(derivatives, '_uw.mat', '.nii');

    end

    bf = bids.File(derivatives, 'verbose', verbose, 'use_schema', false);

    if prefix_based

        if numel(bf.prefix) < 2

            % needs at least 2 characters for this file to have some provenance in the
            % derivatives

            % TODO: files that have been realigned but not resliced have no
            % "prefix" so we may miss some transformation

            return

        else
            % remove the prefix of the last step

            if startsWith(bf.prefix, 's') || startsWith(bf.prefix, 'u')
                bf.prefix = bf.prefix(2:end);

            elseif startsWith(bf.prefix, 'w')
                bf.prefix = bf.prefix(2:end);
                add_deformation_field = true;

            elseif startsWith(bf.prefix, 'rp_a')
                bf.prefix = bf.prefix(4:end);

            elseif startsWith(bf.prefix, 'mean')
                % TODO mean may involve several files from the source (across runs
                % and sessions
                %     prefixes = {
                %                 'mean'
                %                 'meanu'
                %                 'meanua'
                %                };
                return

            else
                % no idea
                return

            end

        end
    end

    % call spm_2_bids what is the filename from the previous step
    new_filename = spm_2_bids(bf.filename, map, verbose);

    sources{1, 1} = fullfile(bf.bids_path, new_filename);

    if add_deformation_field

        % for anatomical data we assume that
        % the deformation field comes from the anatomical file itself
        if (~isempty(bf.modality) && ismember(bf.modality, {'anat'})) || ...
           (~isempty(bf.suffix) && ismember(bf.suffix, covered_suffixes))

            bf.prefix = 'y_';
            bf = bf.update;
            new_filename = spm_2_bids(bf.filename, map, verbose);
            deformation_field = fullfile(bf.bids_path, new_filename);

            % otherwise we can't guess it just from the file name
        else

        end

        sources{2, 1} = deformation_field;

    end

end